--!nocheck
-- Unit tests for pure gameplay logic (economy, grid, critters, quests, schema, formatting).

return function(t)
	local describe, it, expect, Harness = t.describe, t.it, t.expect, t.Harness
	local R = function(path)
		return Harness.requirePath("ReplicatedStorage.Shared." .. path)
	end

	local GameConfig = R("Config.GameConfig")
	local Zones = R("Config.Zones")
	local Upgrades = R("Config.Upgrades")
	local Critters = R("Config.Critters")
	local Progression = R("Config.Progression")
	local Products = R("Config.Products")
	local DataSchema = R("Logic.DataSchema")
	local Economy = R("Logic.Economy")
	local Stats = R("Logic.Stats")
	local DebrisGrid = R("Logic.DebrisGrid")
	local ZoneLayout = R("Logic.ZoneLayout")
	local NetCodec = R("Logic.NetCodec")
	local CritterLogic = R("Logic.CritterLogic")
	local QuestLogic = R("Logic.QuestLogic")
	local Format = R("Util.Format")
	local Rng = R("Util.Rng")
	local RateLimiter = R("Util.RateLimiter")
	local Signal = R("Util.Signal")

	describe("Config integrity", function()
		it("has strictly increasing upgrade costs and stats", function()
			for _, track in { "Vacuums", "Bags", "Boots" } do
				local list = Upgrades[track]
				expect(list[1].cost).toBe(0)
				for i = 2, #list do
					expect(list[i].cost).toBeGreaterThan(list[i - 1].cost)
				end
			end
			for i = 2, #Upgrades.Vacuums do
				expect(Upgrades.Vacuums[i].radius).toBeGreaterThan(Upgrades.Vacuums[i - 1].radius)
				expect(Upgrades.Vacuums[i].power).toBeGreaterOrEqual(Upgrades.Vacuums[i - 1].power)
			end
			for i = 2, #Upgrades.Bags do
				expect(Upgrades.Bags[i].capacity).toBeGreaterThan(Upgrades.Bags[i - 1].capacity)
			end
		end)

		it("has increasing zone values and unlock costs", function()
			expect(Zones[1].unlockCost).toBe(0)
			for i = 2, #Zones do
				expect(Zones[i].id).toBe(i)
				expect(Zones[i].unitValue).toBeGreaterThan(Zones[i - 1].unitValue)
				expect(Zones[i].unlockCost).toBeGreaterThan(Zones[i - 1].unlockCost)
			end
		end)

		it("gives every zone exactly three critters with unique ids", function()
			local seen = {}
			for zoneId = 1, #Zones do
				expect(#Critters.ByZone[zoneId]).toBe(3)
			end
			for _, critter in Critters.List do
				expect(seen[critter.id]).toBeNil()
				seen[critter.id] = true
				expect(Critters.Rarities[critter.rarity]).toBeTruthy()
				expect(Critters.BonusLabels[critter.bonus]).toBeTruthy()
			end
		end)

		it("ships with product ids disabled (0) until configured", function()
			for _, pass in Products.GamePasses do
				expect(type(pass.id)).toBe("number")
			end
			for _, product in Products.DevProducts do
				expect(type(product.id)).toBe("number")
				expect(product.kind == "coins" or product.kind == "boost" or product.kind == "storm").toBeTruthy()
			end
		end)

		it("keeps cell counts within the u16 network index range", function()
			local n = ZoneLayout.cellsPerSide()
			expect(n * n).toBeLessThan(65535)
			expect(GameConfig.CellMax).toBeLessThan(256)
		end)
	end)

	describe("DataSchema", function()
		it("creates a default profile", function()
			local p = DataSchema.new(100)
			expect(p.coins).toBe(0)
			expect(p.maxZone).toBe(1)
			expect(p.firstJoin).toBe(100)
			expect(p.version).toBe(DataSchema.VERSION)
		end)

		it("recovers from nil / garbage", function()
			expect(DataSchema.migrate(nil).coins).toBe(0)
			expect(DataSchema.migrate("corrupt").maxZone).toBe(1)
		end)

		it("sanitizes hostile values", function()
			local p = DataSchema.migrate({
				coins = 0 / 0,
				vacuumTier = 999,
				bagTier = -5,
				maxZone = 3.7,
				critters = { squirrel = { count = 3, golden = "x" }, notreal = { count = 99 } },
				perks = { goldenTouch = 500, fake = 3 },
				equipped = { "squirrel", 42 },
				stats = { lifetimeCoins = math.huge },
			})
			expect(p.coins).toBe(0)
			expect(p.vacuumTier).toBe(#Upgrades.Vacuums)
			expect(p.bagTier).toBe(1)
			expect(p.maxZone).toBe(3)
			expect(p.critters.squirrel.count).toBe(3)
			expect(p.critters.squirrel.golden).toBe(0)
			expect(p.critters.notreal).toBeNil()
			expect(p.perks.goldenTouch).toBe(Progression.PerksById.goldenTouch.maxLevel)
			expect(p.perks.fake).toBeNil()
			expect(#p.equipped).toBe(1)
			expect(p.stats.lifetimeCoins).toBe(0)
			expect(p.settings.music).toBe(true)
		end)

		it("keeps valid existing data", function()
			local p = DataSchema.new(0)
			p.coins = 1234
			p.maxZone = 4
			p.critters.fox = { count = 2, golden = 1 }
			local round = DataSchema.migrate(p)
			expect(round.coins).toBe(1234)
			expect(round.maxZone).toBe(4)
			expect(round.critters.fox.golden).toBe(1)
		end)

		it("strips receipts from the client view", function()
			local p = DataSchema.new(0)
			table.insert(p.receipts, "abc")
			expect(DataSchema.clientView(p).receipts).toBeNil()
			expect(#p.receipts).toBe(1)
		end)
	end)

	describe("Stats", function()
		it("computes base stats", function()
			local p = DataSchema.new(0)
			local s = Stats.compute(p)
			expect(s.radius).toBe(Upgrades.Vacuums[1].radius)
			expect(s.power).toBe(1)
			expect(s.capacity).toBe(Upgrades.Bags[1].capacity)
			expect(s.walkSpeed).toBe(Upgrades.Boots[1].speed)
			expect(s.coinMultiplier).toBe(1)
			expect(s.equipSlots).toBe(GameConfig.BaseEquipSlots)
		end)

		it("stacks passes, boosts, rebirths, perks and critters", function()
			local p = DataSchema.new(0)
			p.rebirths = 2 -- x2
			p.perks.goldenTouch = 2 -- +10%
			p.critters.fox = { count = 1, golden = 1 }
			p.equipped = { "golden:fox" } -- +50%
			p.boosts.coins2x = 10
			local s = Stats.compute(p, { passes = { DoubleCoins = true, VIP = true }, storm = true })
			local expected = 2 * (1 + 0.5 + 0.1) * 2 * Products.VipCoinMultiplier * 2 * Products.GoldenStormMultiplier
			expect(s.coinMultiplier).toBeCloseTo(expected)
			expect(s.equipSlots).toBe(GameConfig.BaseEquipSlots + Products.VipExtraSlots)
		end)

		it("ignores critters beyond the slot count", function()
			local p = DataSchema.new(0)
			p.equipped = { "fox", "fox", "fox", "fox" }
			local s = Stats.compute(p)
			expect(s.coinMultiplier).toBeCloseTo(1 + 0.2 * 3)
		end)

		it("applies the collect boost", function()
			local p = DataSchema.new(0)
			p.boosts.collect2x = 5
			local s = Stats.compute(p)
			expect(s.power).toBe(2)
			expect(s.radius).toBe(Upgrades.Vacuums[1].radius + 3)
		end)
	end)

	describe("Economy", function()
		it("buys upgrades in order and rejects when broke", function()
			local p = DataSchema.new(0)
			local ok, err = Economy.buyNextTier(p, "Vacuums")
			expect(ok).toBe(false)
			expect(err).toBe("Not enough coins")
			p.coins = Upgrades.Vacuums[2].cost + 5
			ok = Economy.buyNextTier(p, "Vacuums")
			expect(ok).toBe(true)
			expect(p.vacuumTier).toBe(2)
			expect(p.coins).toBe(5)
			expect(Economy.buyNextTier(p, "Nope")).toBe(false)
		end)

		it("stops at the max tier", function()
			local p = DataSchema.new(0)
			p.bootsTier = #Upgrades.Boots
			p.coins = 1e18
			local ok, err = Economy.buyNextTier(p, "Boots")
			expect(ok).toBe(false)
			expect(err).toBe("Already maxed out!")
		end)

		it("unlocks zones sequentially", function()
			local p = DataSchema.new(0)
			p.coins = 1e12
			expect(Economy.unlockZone(p, 3)).toBe(false)
			expect(Economy.unlockZone(p, 1)).toBe(false)
			expect(Economy.unlockZone(p, 2)).toBe(true)
			expect(p.maxZone).toBe(2)
			expect(p.coins).toBe(1e12 - Zones[2].unlockCost)
		end)

		it("rebirths with growing cost and keeps critters", function()
			local p = DataSchema.new(0)
			p.critters.squirrel = { count = 4, golden = 0 }
			p.coins = Economy.rebirthCost(0) - 1
			expect(Economy.rebirth(p)).toBe(false)
			p.coins = Economy.rebirthCost(0)
			p.maxZone = 5
			p.vacuumTier = 8
			expect(Economy.rebirth(p)).toBe(true)
			expect(p.rebirths).toBe(1)
			expect(p.coins).toBe(0)
			expect(p.maxZone).toBe(1)
			expect(p.vacuumTier).toBe(1)
			expect(p.rebirthTokens).toBe(1)
			expect(p.critters.squirrel.count).toBe(4)
			expect(Economy.rebirthCost(1)).toBeGreaterThan(Economy.rebirthCost(0))
		end)

		it("applies the head start perk on rebirth", function()
			local p = DataSchema.new(0)
			p.perks.headStart = 2
			p.coins = Economy.rebirthCost(0)
			Economy.rebirth(p)
			expect(p.vacuumTier).toBe(3)
			expect(p.bagTier).toBe(3)
		end)

		it("awards a bonus token every 5th rebirth", function()
			expect(Economy.rebirthTokens(4)).toBe(1)
			expect(Economy.rebirthTokens(5)).toBe(2)
		end)

		it("buys perks with tokens", function()
			local p = DataSchema.new(0)
			expect(Economy.buyPerk(p, "goldenTouch")).toBe(false)
			p.rebirthTokens = 1
			expect(Economy.buyPerk(p, "goldenTouch")).toBe(true)
			expect(p.perks.goldenTouch).toBe(1)
			expect(p.rebirthTokens).toBe(0)
			expect(Economy.buyPerk(p, "unknown")).toBe(false)
		end)

		it("scales coin packs with progression", function()
			local p = DataSchema.new(0)
			local early = Economy.coinPackAmount(p, 3)
			expect(early).toBe(Upgrades.Bags[1].capacity * 3)
			p.maxZone = 4
			p.bagTier = 6
			expect(Economy.coinPackAmount(p, 3)).toBeGreaterThan(early * 100)
		end)

		it("rounds sale values", function()
			expect(Economy.sellValue(10, 1.26)).toBe(13)
			expect(Economy.sellValue(0, 5)).toBe(0)
		end)
	end)

	describe("DebrisGrid", function()
		local function makeGrid(mask)
			return DebrisGrid.new({ cols = 10, rows = 10, cellSize = 6, originX = 0, originZ = 0, cellMax = 6, mask = mask })
		end

		it("fills and tracks remaining units", function()
			local g = makeGrid({ [0] = true })
			g:fill()
			expect(g.activeCells).toBe(99)
			expect(g.remaining).toBe(99 * 6)
			expect(g:get(0)).toBe(0)
			expect(g:cleanFraction()).toBe(0)
		end)

		it("collects within radius, respecting power and bag space", function()
			local g = makeGrid()
			g:fill()
			local changed = {}
			local got = g:collect(3, 3, 1, 2, 100, changed) -- only cell 0
			expect(got).toBe(2)
			expect(g:get(0)).toBe(4)
			expect(#changed).toBe(1)
			local limited = g:collect(30, 30, 20, 6, 7)
			expect(limited).toBe(7)
			expect(g.remaining).toBe(600 - 9)
		end)

		it("returns 0 outside the grid or when empty", function()
			local g = makeGrid()
			g:fill()
			expect(g:collect(-100, -100, 5, 5, 100)).toBe(0)
			g:fill(0)
			expect(g:collect(30, 30, 50, 6, 1000)).toBe(0)
			expect(g:cleanFraction()).toBe(1)
		end)

		it("can be fully cleared and never goes negative", function()
			local g = makeGrid()
			g:fill()
			local total = 0
			for _ = 1, 10 do
				total += g:collect(30, 30, 100, 6, 1e9)
			end
			expect(total).toBe(600)
			expect(g.remaining).toBe(0)
		end)

		it("round-trips snapshots and ignores masked cells on load", function()
			local g = makeGrid({ [5] = true })
			g:fill()
			g:collect(3, 3, 1, 6, 100)
			local snap = g:snapshot()
			local h = makeGrid({ [5] = true })
			h:load(snap)
			expect(h.remaining).toBe(g.remaining)
			expect(h:get(0)).toBe(0)
			expect(h:get(5)).toBe(0)
		end)

		it("maps positions to cells", function()
			local g = makeGrid()
			expect(g:indexAt(7, 1)).toBe(1)
			expect(g:indexAt(1, 7)).toBe(10)
			expect(g:indexAt(-1, 0)).toBeNil()
			local x, z = g:cellCenter(11)
			expect(x).toBe(9)
			expect(z).toBe(9)
		end)
	end)

	describe("ZoneLayout", function()
		it("places deterministic props away from the path and pads", function()
			for zoneId = 1, #Zones do
				local a = ZoneLayout.props(zoneId)
				expect(#a).toBeGreaterThan(5)
				for _, prop in a do
					expect(math.abs(prop.z)).toBeGreaterThan(10)
				end
			end
		end)

		it("masks some cells but keeps most of the zone playable", function()
			local n = ZoneLayout.cellsPerSide()
			for zoneId = 1, #Zones do
				local masked = 0
				for _ in ZoneLayout.mask(zoneId) do
					masked += 1
				end
				expect(masked).toBeGreaterThan(0)
				expect(masked).toBeLessThan(n * n * 0.3)
			end
		end)

		it("resolves positions to zones", function()
			expect(ZoneLayout.zoneAt(0, 0)).toBe(0)
			local cx = ZoneLayout.center(3)
			expect(ZoneLayout.zoneAt(cx + 10, 20)).toBe(3)
			expect(ZoneLayout.zoneAt(cx + 100, 0)).toBeNil() -- corridor
			expect(ZoneLayout.zoneAt(-500, 0)).toBeNil()
		end)

		it("keeps sell pads and spawn inside the zone", function()
			for zoneId = 1, #Zones do
				for _, pad in ZoneLayout.sellPads(zoneId) do
					expect(ZoneLayout.zoneAt(pad.x, pad.z)).toBe(zoneId)
				end
				local sx, sz = ZoneLayout.spawnPoint(zoneId)
				expect(ZoneLayout.zoneAt(sx, sz)).toBe(zoneId)
			end
		end)
	end)

	describe("NetCodec", function()
		it("round-trips dirty cells", function()
			local values = { [1] = { [0] = 3, [400] = 0 }, [8] = { [12] = 6 } }
			local dirty = { [1] = { [0] = true, [400] = true }, [8] = { [12] = true } }
			local buf = NetCodec.encodeDirty(dirty, function(z, i)
				return values[z][i]
			end)
			local seen = {}
			NetCodec.decodeDeltas(buf, function(z, i, a)
				seen[z .. ":" .. i] = a
			end)
			expect(seen["1:0"]).toBe(3)
			expect(seen["1:400"]).toBe(0)
			expect(seen["8:12"]).toBe(6)
			expect(NetCodec.encodeDirty({}, function()
				return 0
			end)).toBeNil()
		end)

		it("ignores truncated buffers", function()
			local bad = buffer.create(3)
			buffer.writeu16(bad, 0, 50)
			local calls = 0
			NetCodec.decodeDeltas(bad, function()
				calls += 1
			end)
			expect(calls).toBe(0)
		end)
	end)

	describe("CritterLogic", function()
		it("reports odds summing to 1 for every zone", function()
			for zoneId = 1, #Zones do
				local sum = 0
				for _, entry in CritterLogic.odds(zoneId) do
					sum += entry.chance
				end
				expect(sum).toBeCloseTo(1)
			end
		end)

		it("respects pity and first-find guarantees", function()
			local never = function()
				return 0.999999
			end
			expect(CritterLogic.roll(never, 1, 1, 0, false)).toBeNil()
			expect(CritterLogic.roll(never, 1, 1, GameConfig.CritterPityTicks, false)).toBeTruthy()
			expect(CritterLogic.roll(never, 1, 1, GameConfig.FirstCritterGuaranteeTicks, true)).toBeTruthy()
			local always = function()
				return 0
			end
			expect(CritterLogic.roll(always, 2, 1, 0, false)).toBe("crow")
		end)

		it("finds roughly the configured rate", function()
			local rng = Rng.new(42)
			local finds = 0
			local n = 200000
			for _ = 1, n do
				if CritterLogic.roll(function()
					return rng:next()
				end, 1, 1, 0, false) then
					finds += 1
				end
			end
			local rate = finds / n
			expect(rate).toBeGreaterThan(GameConfig.CritterBaseFindChance * 0.8)
			expect(rate).toBeLessThan(GameConfig.CritterBaseFindChance * 1.2)
		end)

		it("merges duplicates into golden critters, protecting equipped copies", function()
			local p = DataSchema.new(0)
			CritterLogic.add(p, "squirrel", 5)
			p.equipped = { "squirrel" }
			expect(CritterLogic.makeGolden(p, "squirrel")).toBe(false)
			CritterLogic.add(p, "squirrel", 1)
			expect(CritterLogic.makeGolden(p, "squirrel")).toBe(true)
			expect(p.critters.squirrel.count).toBe(1)
			expect(p.critters.squirrel.golden).toBe(1)
			expect(p.discovered.squirrel).toBe(true)
		end)

		it("validates equip lists", function()
			local p = DataSchema.new(0)
			CritterLogic.add(p, "fox", 1)
			expect(CritterLogic.setEquipped(p, { "fox", "fox" }, 3)).toBe(false)
			expect(CritterLogic.setEquipped(p, { "golden:fox" }, 3)).toBe(false)
			expect(CritterLogic.setEquipped(p, { "crab" }, 3)).toBe(false)
			expect(CritterLogic.setEquipped(p, { 1 }, 3)).toBe(false)
			expect(CritterLogic.setEquipped(p, { "fox" }, 0)).toBe(false)
			expect(CritterLogic.setEquipped(p, { "fox" }, 3)).toBe(true)
			expect(p.equipped[1]).toBe("fox")
		end)

		it("picks the best loadout", function()
			local p = DataSchema.new(0)
			CritterLogic.add(p, "squirrel", 3)
			CritterLogic.add(p, "fox", 1)
			p.critters.fox.golden = 1
			local best = CritterLogic.bestLoadout(p, 2)
			expect(best[1]).toBe("golden:fox")
			expect(best[2]).toBe("fox")
		end)
	end)

	describe("QuestLogic", function()
		it("generates 3 distinct deterministic quests per day", function()
			local p = DataSchema.new(0)
			local a = QuestLogic.generate(100, 55, p)
			local b = QuestLogic.generate(100, 55, p)
			expect(#a).toBe(GameConfig.DailyQuestCount)
			expect(a).toEqual(b)
			local stats = {}
			for _, q in a do
				local template = QuestLogic.TemplateById[q.id]
				expect(stats[template.stat]).toBeNil()
				stats[template.stat] = true
				expect(q.target).toBeGreaterThan(0)
			end
		end)

		it("refreshes on a new day only", function()
			local p = DataSchema.new(0)
			expect(QuestLogic.ensureToday(p, 86400 * 10 + 5, 1)).toBe(true)
			expect(QuestLogic.ensureToday(p, 86400 * 10 + 500, 1)).toBe(false)
			expect(QuestLogic.ensureToday(p, 86400 * 11 + 1, 1)).toBe(true)
		end)

		it("tracks progress, completes and claims once", function()
			local p = DataSchema.new(0)
			p.quests.day = 1
			p.quests.list = {
				{ id = "sell", target = 2, progress = 0, claimed = false },
				{ id = "critter", target = 1, progress = 0, claimed = false },
			}
			expect(#QuestLogic.addProgress(p, "sells", 1)).toBe(0)
			expect(QuestLogic.claim(p, 1)).toBe(false)
			local done = QuestLogic.addProgress(p, "sells", 5)
			expect(done[1]).toBe(1)
			expect(p.quests.list[1].progress).toBe(2)
			local ok, coins = QuestLogic.claim(p, 1)
			expect(ok).toBe(true)
			expect(coins).toBeGreaterThan(0)
			expect(p.coins).toBe(coins)
			expect(QuestLogic.claim(p, 1)).toBe(false)
			expect(QuestLogic.claim(p, 99)).toBe(false)
		end)

		it("awards a token for finishing all quests after the first rebirth", function()
			local p = DataSchema.new(0)
			p.rebirths = 1
			p.quests.list = { { id = "sell", target = 1, progress = 1, claimed = false } }
			local ok, _, tokens = QuestLogic.claim(p, 1)
			expect(ok).toBe(true)
			expect(tokens).toBe(1)
			expect(p.rebirthTokens).toBe(1)
		end)

		it("advances and resets the login streak", function()
			local p = DataSchema.new(0)
			local day = 86400
			expect(QuestLogic.updateStreak(p, day * 5)).toBe(true)
			expect(p.streak.count).toBe(1)
			local ok = QuestLogic.claimStreak(p, day * 5)
			expect(ok).toBe(true)
			expect(QuestLogic.claimStreak(p, day * 5 + 10)).toBe(false)
			QuestLogic.updateStreak(p, day * 6)
			expect(p.streak.count).toBe(2)
			QuestLogic.updateStreak(p, day * 9) -- missed days
			expect(p.streak.count).toBe(1)
		end)

		it("grants the day-7 boost and wraps the cycle", function()
			local p = DataSchema.new(0)
			p.streak.lastDay = 9
			p.streak.count = 6
			local ok, _, boost = QuestLogic.claimStreak(p, 86400 * 10)
			expect(ok).toBe(true)
			expect(p.streak.count).toBe(7)
			expect(boost).toBeGreaterThan(0)
			expect(p.boosts.coins2x).toBe(boost)
			QuestLogic.updateStreak(p, 86400 * 11)
			expect(p.streak.count).toBe(1)
		end)
	end)

	describe("Utilities", function()
		it("formats numbers", function()
			expect(Format.abbreviate(0)).toBe("0")
			expect(Format.abbreviate(999)).toBe("999")
			expect(Format.abbreviate(1000)).toBe("1K")
			expect(Format.abbreviate(1234)).toBe("1.23K")
			expect(Format.abbreviate(15300000)).toBe("15.3M")
			expect(Format.abbreviate(250000000)).toBe("250M")
			expect(Format.abbreviate(-1500)).toBe("-1.5K")
			expect(Format.commas(1234567)).toBe("1,234,567")
			expect(Format.time(75)).toBe("1:15")
			expect(Format.time(3725)).toBe("1:02:05")
			expect(Format.percent(0.456)).toBe("46%")
		end)

		it("produces deterministic random sequences", function()
			local a, b = Rng.new(7), Rng.new(7)
			for _ = 1, 20 do
				local x = a:next()
				expect(x).toBe(b:next())
				expect(x >= 0 and x < 1).toBeTruthy()
			end
			local c = Rng.new(8)
			expect(c:next()).never(Rng.new(7):next())
			expect(Rng.hashString("abc")).toBe(Rng.hashString("abc"))
		end)

		it("rate limits with a token bucket", function()
			local now = 0
			local limiter = RateLimiter.new(2, 3, function()
				return now
			end)
			expect(limiter:check("p")).toBe(true)
			expect(limiter:check("p")).toBe(true)
			expect(limiter:check("p")).toBe(true)
			expect(limiter:check("p")).toBe(false)
			now = 1
			expect(limiter:check("p")).toBe(true)
			expect(limiter:check("other")).toBe(true)
		end)

		it("dispatches signals and survives handler errors", function()
			local s = Signal.new()
			local calls = 0
			s:Connect(function()
				error("boom")
			end)
			local c = s:Connect(function(n)
				calls += n
			end)
			Harness.silenceWarnings = true
			s:Fire(2)
			c:Disconnect()
			s:Fire(5)
			Harness.silenceWarnings = false
			expect(calls).toBe(2)
			local once = 0
			s:Once(function()
				once += 1
			end)
			s:Fire(0)
			s:Fire(0)
			expect(once).toBe(1)
		end)
	end)
end
