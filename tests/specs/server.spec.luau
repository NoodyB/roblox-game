--!nocheck
-- Server service tests with mocked engine services: persistence + session locking, receipts,
-- the collection/sell loop, anti-cheat and zone access, quests and the action dispatcher.

return function(t)
	local describe, it, expect, Harness, Mocks = t.describe, t.it, t.expect, t.Harness, t.Mocks

	local mocks = Mocks.install(Harness)
	local R = function(path)
		return Harness.requirePath(path)
	end

	local GameConfig = R("ReplicatedStorage.Shared.Config.GameConfig")
	local Zones = R("ReplicatedStorage.Shared.Config.Zones")
	local Products = R("ReplicatedStorage.Shared.Config.Products")
	local ZoneLayout = R("ReplicatedStorage.Shared.Logic.ZoneLayout")
	local Economy = R("ReplicatedStorage.Shared.Logic.Economy")
	local Net = R("ServerScriptService.Server.Services.Net")
	local DataService = R("ServerScriptService.Server.Services.DataService")
	local PassService = R("ServerScriptService.Server.Services.PassService")
	local PlayerService = R("ServerScriptService.Server.Services.PlayerService")
	local CritterService = R("ServerScriptService.Server.Services.CritterService")
	local DebrisService = R("ServerScriptService.Server.Services.DebrisService")
	local QuestService = R("ServerScriptService.Server.Services.QuestService")
	local ShopService = R("ServerScriptService.Server.Services.ShopService")
	local MonetizationService = R("ServerScriptService.Server.Services.MonetizationService")
	local Events = R("ServerScriptService.Server.Services.Events")

	-- capture network traffic instead of sending it
	local fired = {}
	Net.fire = function(name, player, ...)
		table.insert(fired, { name = name, player = player, args = { ... } })
	end
	Net.fireAll = function(name, ...)
		table.insert(fired, { name = name, all = true, args = { ... } })
	end
	Net.notify = function(player, kind, text)
		table.insert(fired, { name = "Notify", player = player, args = { kind, text } })
	end
	local function lastEffect(kind)
		for i = #fired, 1, -1 do
			if fired[i].name == "Effect" and fired[i].args[1] == kind then
				return fired[i]
			end
		end
		return nil
	end

	DataService._wait = function() end
	Harness.setJobId("job-A")

	-- Init in dependency order (skip Net:Init/WorldService:Init which need real instances)
	DataService:Init()
	PassService:Init()
	PlayerService:Init()
	CritterService:Init()
	DebrisService:Init()
	QuestService:Init()
	ShopService:Init()
	MonetizationService:Init()

	local store = mocks.DataStoreService.store(GameConfig.DataStoreName)
	local nextUserId = 100

	local function join()
		nextUserId += 1
		local player = mocks.Players.add(nextUserId)
		DataService._onPlayerAdded(player)
		return player
	end

	local function zonePoint(zoneId, dx, dz)
		local cx = ZoneLayout.center(zoneId)
		return Vector3.new(cx + (dx or 0), 3, dz or 30)
	end

	describe("DataService", function()
		it("creates and locks a new profile", function()
			local player = join()
			local profile = DataService.get(player)
			expect(profile).toBeTruthy()
			expect(profile.coins).toBe(0)
			local record = store.data["Player_" .. player.UserId]
			expect(record.lock.jobId).toBe("job-A")
		end)

		it("loads existing data and migrates it", function()
			nextUserId += 1
			store.data["Player_" .. nextUserId] = { data = { coins = 555, maxZone = 2 }, savedAt = 1 }
			local player = mocks.Players.add(nextUserId)
			DataService._onPlayerAdded(player)
			local profile = DataService.get(player)
			expect(profile.coins).toBe(555)
			expect(profile.maxZone).toBe(2)
			expect(profile.bagTier).toBe(1)
		end)

		it("saves while keeping the lock and releases it on leave", function()
			local player = join()
			local profile = DataService.get(player)
			profile.coins = 42
			expect(DataService.save(player)).toBe(true)
			local key = "Player_" .. player.UserId
			expect(store.data[key].data.coins).toBe(42)
			expect(store.data[key].lock.jobId).toBe("job-A")
			mocks.Players.remove(player)
			expect(store.data[key].lock).toBeNil()
			expect(DataService.get(player)).toBeNil()
		end)

		it("waits for a live lock, then takes over after the retry budget", function()
			nextUserId += 1
			local key = "Player_" .. nextUserId
			store.data[key] = { data = { coins = 7 }, lock = { jobId = "job-B", time = os.time() } }
			local player = mocks.Players.add(nextUserId)
			DataService._onPlayerAdded(player)
			expect(DataService.get(player).coins).toBe(7)
			expect(store.data[key].lock.jobId).toBe("job-A")
		end)

		it("takes stale locks immediately", function()
			nextUserId += 1
			local key = "Player_" .. nextUserId
			store.data[key] = { data = { coins = 9 }, lock = { jobId = "job-B", time = os.time() - 10_000 } }
			local writesBefore = store.writes
			local player = mocks.Players.add(nextUserId)
			DataService._onPlayerAdded(player)
			expect(DataService.get(player).coins).toBe(9)
			expect(store.writes).toBe(writesBefore + 1)
		end)

		it("stops saving and kicks when another server steals the session", function()
			local player = join()
			local key = "Player_" .. player.UserId
			store.data[key].lock = { jobId = "job-C", time = os.time() }
			DataService.get(player).coins = 999
			expect(DataService.save(player)).toBe(false)
			local saved = store.data[key].data
			expect(saved == nil or saved.coins ~= 999).toBeTruthy()
			expect(player.kicked).toBeTruthy()
		end)

		it("kicks instead of playing on a blank profile when loading fails", function()
			store.failNext = 99
			local player = join()
			store.failNext = 0
			expect(DataService.get(player)).toBeNil()
			expect(player.kicked).toBeTruthy()
		end)

		it("retries transient save failures", function()
			local player = join()
			DataService.get(player).coins = 31
			store.failNext = 2
			expect(DataService.save(player)).toBe(true)
			expect(store.data["Player_" .. player.UserId].data.coins).toBe(31)
		end)

		it("saves and releases everyone on shutdown", function()
			local a, b = join(), join()
			DataService.get(a).coins = 5
			DataService.get(b).coins = 6
			DataService._onClose()
			expect(store.data["Player_" .. a.UserId].data.coins).toBe(5)
			expect(store.data["Player_" .. b.UserId].lock).toBeNil()
		end)
	end)

	describe("Collection loop", function()
		it("vacuums debris into the bag and shrinks the grid", function()
			local player = join()
			local profile = DataService.get(player)
			local zone = DebrisService.getZone(1)
			local before = zone.grid.remaining
			DebrisService.step(player, zonePoint(1), 100)
			expect(profile.bagUnits).toBeGreaterThan(0)
			expect(zone.grid.remaining).toBe(before - profile.bagUnits)
			expect(profile.bagValue).toBe(profile.bagUnits * Zones[1].unitValue)
			expect(profile.tutorialStep).toBe(2)
		end)

		it("never exceeds bag capacity and reports a full bag", function()
			local player = join()
			local profile = DataService.get(player)
			local stats = PlayerService.getStats(player)
			for i = 1, 30 do
				DebrisService.step(player, zonePoint(1, (i % 10) * 4 - 20, 30 + (i % 3) * 5), 200 + i)
			end
			expect(profile.bagUnits).toBe(stats.capacity)
			expect(lastEffect("bagFull")).toBeTruthy()
		end)

		it("sells on a pad using the coin multiplier", function()
			local player = join()
			local profile = DataService.get(player)
			profile.bagUnits = 20
			profile.bagValue = 20
			profile.rebirths = 1
			PlayerService.refresh(player)
			local pad = ZoneLayout.sellPads(1)[1]
			DebrisService.step(player, Vector3.new(pad.x, 3, pad.z), 300)
			expect(profile.coins).toBe(30) -- 20 * 1.5
			expect(profile.bagUnits).toBe(0)
			expect(profile.stats.sells).toBe(1)
			expect(lastEffect("sell").args[2].coins).toBe(30)
		end)

		it("blocks collection in locked zones and teleports the player back", function()
			local player = join()
			local profile = DataService.get(player)
			local character = Mocks.instance("Model")
			player.Character = character
			DebrisService.step(player, zonePoint(3), 400)
			expect(profile.bagUnits).toBe(0)
			expect(character.pivot).toBeTruthy()
			local x = character.pivot.Position.X
			expect(ZoneLayout.zoneAt(x, character.pivot.Position.Z)).toBe(1)
		end)

		it("rejects impossible movement (speed hacks)", function()
			local player = join()
			local profile = DataService.get(player)
			local session = PlayerService.getSession(player)
			session.graceUntil = 0
			DebrisService.step(player, zonePoint(1, -40, 40), 500) -- establishes position
			local bag = profile.bagUnits
			DebrisService.step(player, zonePoint(1, 40, -40), 500.2) -- 110+ studs in 0.2s
			expect(profile.bagUnits).toBe(bag)
			expect(session.flags).toBe(1)
		end)

		it("auto-sells for Auto Sell pass owners", function()
			local player = join()
			local profile = DataService.get(player)
			PassService._checkOwnership(player)
			local passes = PassService.passes(player)
			passes.AutoSell = true
			PlayerService.refresh(player)
			local stats = PlayerService.getStats(player)
			profile.bagUnits = stats.capacity
			profile.bagValue = stats.capacity
			DebrisService.step(player, zonePoint(1, 10, -30), 600)
			expect(profile.coins).toBeGreaterOrEqual(stats.capacity)
		end)

		it("gives squad bonuses to players cleaning together", function()
			local a, b = join(), join()
			local pa, pb = DataService.get(a), DataService.get(b)
			-- far from players left over by earlier tests
			DebrisService.step(b, zonePoint(1, -50, -55), 700)
			DebrisService.step(a, zonePoint(1, -46, -55), 700)
			local expectedValue = pa.bagUnits * Zones[1].unitValue * (1 + GameConfig.SquadBonusPerPlayer)
			expect(pa.bagValue).toBeCloseTo(expectedValue)
			expect(pb.bagUnits).toBeGreaterThan(0)
		end)

		it("rewards contributors when a zone is cleared and refills with a golden wave", function()
			local player = join()
			local profile = DataService.get(player)
			local zone = DebrisService.getZone(2)
			zone.contributions[player] = 100
			local coinsBefore = profile.coins
			local oldDelay = GameConfig.GustDelay
			GameConfig.GustDelay = 0
			DebrisService._startClear(2)
			expect(profile.coins).toBeGreaterThan(coinsBefore)
			expect(profile.stats.zoneClears).toBe(1)
			task.wait(0.05)
			GameConfig.GustDelay = oldDelay
			expect(zone.wave).toBe(2)
			expect(zone.golden).toBe(true)
			expect(zone.clearing).toBe(false)
			expect(zone.grid.remaining).toBe(zone.grid.capacity)
			-- the next two clears: golden -> normal, then the cooldown blocks another golden wave
			GameConfig.GustDelay = 0
			DebrisService._startClear(2)
			task.wait(0.05)
			expect(zone.golden).toBe(false)
			DebrisService._startClear(2)
			task.wait(0.05)
			GameConfig.GustDelay = oldDelay
			expect(zone.golden).toBe(false)
		end)
	end)

	describe("Critters", function()
		it("guarantees a first critter and auto-equips it", function()
			local player = join()
			local profile = DataService.get(player)
			for i = 1, GameConfig.FirstCritterGuaranteeTicks + 1 do
				CritterService.onCollectTick(player, 1)
			end
			expect(profile.stats.crittersFound).toBeGreaterOrEqual(1)
			expect(#profile.equipped).toBeGreaterOrEqual(1)
			expect(lastEffect("critter")).toBeTruthy()
		end)
	end)

	describe("Actions", function()
		it("rejects unknown actions and bad payloads", function()
			local player = join()
			expect(Net._dispatch(player, "GiveMeCoins", 1e9).ok).toBe(false)
			expect(Net._dispatch(player, 123, nil).ok).toBe(false)
			expect(Net._dispatch(player, "BuyUpgrade", { evil = true }).ok).toBe(false)
			expect(Net._dispatch(player, "UnlockZone", "2").ok).toBe(false)
			expect(Net._dispatch(player, "Teleport", 5).ok).toBe(false)
			expect(Net._dispatch(player, "Teleport", 0 / 0).ok).toBe(false)
			expect(Net._dispatch(player, "Teleport", math.huge).ok).toBe(false)
			expect(Net._dispatch(player, "Teleport", 1.5).ok).toBe(false)
			expect(Net._dispatch(player, "ClaimQuest", 0 / 0).ok).toBe(false)
			expect(Net._dispatch(player, "EquipCritters", { [1] = "fox", evil = "x" }).ok).toBe(false)
		end)

		it("buys upgrades through the dispatcher", function()
			local player = join()
			local profile = DataService.get(player)
			profile.coins = 1000
			local result = Net._dispatch(player, "BuyUpgrade", "Vacuums")
			expect(result.ok).toBe(true)
			expect(profile.vacuumTier).toBe(2)
			expect(PlayerService.getStats(player).radius).toBe(6)
		end)

		it("unlocks zones through the gate prompt path", function()
			local player = join()
			local profile = DataService.get(player)
			profile.coins = Zones[2].unlockCost
			local ok = ShopService.unlockZone(player, 2)
			expect(ok).toBe(true)
			expect(profile.maxZone).toBe(2)
			expect(profile.coins).toBe(0)
		end)

		it("rate limits action spam", function()
			local player = join()
			local rejected = 0
			for _ = 1, 40 do
				if Net._dispatch(player, "AutoEquip", nil).err == "Slow down!" then
					rejected += 1
				end
			end
			expect(rejected).toBeGreaterThan(10)
		end)

		it("claims completed quests exactly once", function()
			local player = join()
			local profile = DataService.get(player)
			profile.quests.list[1].progress = profile.quests.list[1].target
			local first = Net._dispatch(player, "ClaimQuest", 1)
			expect(first.ok).toBe(true)
			local second = Net._dispatch(player, "ClaimQuest", 1)
			expect(second.ok).toBe(false)
		end)

		it("rebirths and sends the player to the hub", function()
			local player = join()
			local profile = DataService.get(player)
			player.Character = Mocks.instance("Model")
			profile.coins = Economy.rebirthCost(0)
			profile.maxZone = 4
			local result = Net._dispatch(player, "Rebirth", nil)
			expect(result.ok).toBe(true)
			expect(profile.rebirths).toBe(1)
			expect(profile.maxZone).toBe(1)
			expect(PlayerService.getStats(player).rebirthMultiplier).toBe(1.5)
		end)
	end)

	describe("MonetizationService", function()
		local coinsProduct = Products.ProductByKey.CoinsSmall
		local stormProduct = Products.ProductByKey.GoldenStorm
		coinsProduct.id = 9001
		Products.ProductById[9001] = coinsProduct
		stormProduct.id = 9002
		Products.ProductById[9002] = stormProduct
		local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
		local NotYet = Enum.ProductPurchaseDecision.NotProcessedYet

		it("grants a coin pack once, even when the callback repeats", function()
			local player = join()
			local profile = DataService.get(player)
			local receipt = { PlayerId = player.UserId, ProductId = 9001, PurchaseId = "p-1" }
			expect(MonetizationService.processReceipt(receipt)).toBe(Granted)
			local afterFirst = profile.coins
			expect(afterFirst).toBe(Economy.coinPackAmount(profile, coinsProduct.amount))
			expect(MonetizationService.processReceipt(receipt)).toBe(Granted)
			expect(profile.coins).toBe(afterFirst)
			expect(store.data["Player_" .. player.UserId].data.receipts[1]).toBe("p-1")
		end)

		it("does not report success until the grant is saved", function()
			local player = join()
			local profile = DataService.get(player)
			local receipt = { PlayerId = player.UserId, ProductId = 9001, PurchaseId = "p-2" }
			store.failNext = 3
			expect(MonetizationService.processReceipt(receipt)).toBe(NotYet)
			local coins = profile.coins
			expect(coins).toBeGreaterThan(0)
			-- Roblox retries later: no double grant, and now it is saved
			expect(MonetizationService.processReceipt(receipt)).toBe(Granted)
			expect(profile.coins).toBe(coins)
		end)

		it("defers unknown products and absent players", function()
			local player = join()
			expect(MonetizationService.processReceipt({ PlayerId = player.UserId, ProductId = 1, PurchaseId = "x" })).toBe(NotYet)
			expect(MonetizationService.processReceipt({ PlayerId = 999999, ProductId = 9001, PurchaseId = "y" })).toBe(NotYet)
		end)

		it("starts a server-wide storm that boosts everyone's coins", function()
			local buyer, other = join(), join()
			local before = PlayerService.getStats(other).coinMultiplier
			expect(MonetizationService.processReceipt({ PlayerId = buyer.UserId, ProductId = 9002, PurchaseId = "s-1" })).toBe(Granted)
			task.wait(0.01) -- storm start is deferred
			expect(PlayerService.stormActive()).toBe(true)
			expect(PlayerService.getStats(other).coinMultiplier).toBeCloseTo(before * Products.GoldenStormMultiplier)
		end)
	end)

	describe("Events wiring", function()
		it("tracks quest progress from gameplay events", function()
			local player = join()
			local profile = DataService.get(player)
			profile.quests.list = { { id = "sell", target = 2, progress = 0, claimed = false } }
			Events.Sold:Fire(player, 10, 5)
			Events.Sold:Fire(player, 10, 5)
			expect(profile.quests.list[1].progress).toBe(2)
		end)
	end)
end
