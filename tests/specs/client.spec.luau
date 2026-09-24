--!nocheck
-- Client tests: builds the entire HUD, every window, the debris renderer, effects and world views
-- against validated instances, feeds them realistic state, and clicks buttons.

return function(t)
	local describe, it, expect, Harness, ClientEnv = t.describe, t.it, t.expect, t.Harness, t.ClientEnv
	local env = ClientEnv.install(Harness)

	local R = function(path)
		return Harness.requirePath(path)
	end
	local Shared = "ReplicatedStorage.Shared."
	local Client = "StarterPlayer.StarterPlayerScripts.Client."

	local GameConfig = R(Shared .. "Config.GameConfig")
	local Zones = R(Shared .. "Config.Zones")
	local DataSchema = R(Shared .. "Logic.DataSchema")
	local Stats = R(Shared .. "Logic.Stats")
	local DebrisGrid = R(Shared .. "Logic.DebrisGrid")
	local ZoneLayout = R(Shared .. "Logic.ZoneLayout")
	local NetCodec = R(Shared .. "Logic.NetCodec")
	local QuestLogic = R(Shared .. "Logic.QuestLogic")

	local ClientState = R(Client .. "Controllers.ClientState")
	local Audio = R(Client .. "Controllers.Audio")
	local DebrisRenderer = R(Client .. "Controllers.DebrisRenderer")
	local Effects = R(Client .. "Controllers.Effects")
	local WorldView = R(Client .. "Controllers.WorldView")
	local CritterFollowers = R(Client .. "Controllers.CritterFollowers")
	local Tutorial = R(Client .. "Controllers.Tutorial")
	local Input = R(Client .. "Controllers.Input")
	local Responsive = R(Client .. "UI.Responsive")
	local HUD = R(Client .. "UI.HUD")
	local Notifications = R(Client .. "UI.Notifications")
	local WindowManager = R(Client .. "UI.WindowManager")

	local function makeState()
		local profile = DataSchema.new(os.time())
		profile.coins = 5_000_000
		profile.maxZone = 3
		profile.critters = { squirrel = { count = 6, golden = 1 }, fox = { count = 1, golden = 0 } }
		profile.discovered = { squirrel = true, fox = true }
		profile.equipped = { "golden:squirrel", "fox" }
		profile.boosts.coins2x = 120
		QuestLogic.ensureToday(profile, os.time(), 1)
		profile.quests.list[1].progress = profile.quests.list[1].target
		QuestLogic.updateStreak(profile, os.time())
		local state = DataSchema.clientView(profile)
		state.derived = Stats.compute(profile)
		state.passes = { VIP = true }
		state.storm = { endsAt = 0, by = "" }
		state.temporaryData = true
		return state
	end

	local function snapshot()
		local result = {}
		for zoneId = 1, #Zones do
			local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
			local grid = DebrisGrid.new({ cols = cols, rows = rows, cellSize = GameConfig.CellSize, originX = originX, originZ = originZ, cellMax = GameConfig.CellMax, mask = ZoneLayout.mask(zoneId) })
			grid:fill()
			result[tostring(zoneId)] = { wave = 1, golden = zoneId == 2, cells = grid:snapshot() }
		end
		return result
	end

	local state = makeState()
	local debris = snapshot()
	local guis = {}

	describe("client boot", function()
		it("initializes every controller", function()
			Audio:Init()
			ClientState:Init()
			DebrisRenderer:Init()
			Effects:Init()
			WorldView:Init()
			CritterFollowers:Init()
			Tutorial:Init()
			Input:Init()
		end)

		it("builds the HUD, notifications and all windows", function()
			Responsive.start()
			guis.hud = Responsive.screen("SweepHUD", 1, env.playerGui)
			guis.windows = Responsive.screen("SweepWindows", 5, env.playerGui)
			guis.fx = Responsive.screen("SweepFX", 10, env.playerGui)
			HUD.mount(guis.hud)
			HUD.setDebrisQueries(DebrisRenderer.cleanFraction, DebrisRenderer.isGolden)
			Tutorial.mount(guis.hud)
			WindowManager.mount(guis.windows)
			Notifications.mount(guis.fx)
			Effects.mount(guis.fx)
			WorldView.mount(guis.fx)
			local Windows = Harness.findPath("StarterPlayer.StarterPlayerScripts.Client.UI.Windows")
			local request = ClientState.request
			WindowManager.register(Harness.require(Windows.ShopWindow)(request))
			WindowManager.register(Harness.require(Windows.CrittersWindow)(request))
			WindowManager.register(Harness.require(Windows.QuestsWindow)(request))
			WindowManager.register(Harness.require(Windows.RebirthWindow)(request))
			WindowManager.register(Harness.require(Windows.TeleportWindow)(request, function() end))
			WindowManager.register(Harness.require(Windows.StoreWindow)())
			WindowManager.register(Harness.require(Windows.SettingsWindow)(request))
			local count = #env.playerGui:GetDescendants()
			print(string.format("      UI instances built: %d", count))
			expect(count).toBeGreaterThan(300)
		end)

		it("completes the handshake and applies state everywhere", function()
			env.requestHandler = function(action, payload)
				table.insert(env.requests, { action = action, payload = payload })
				if action == "Hello" then
					return { ok = true, data = { state = state, debris = debris } }
				end
				return { ok = true }
			end
			ClientState.Changed:Connect(function(s)
				HUD.refresh(s)
				WindowManager.refresh(s)
				Audio.applySettings(s.settings)
			end)
			ClientState:Start()
			task.wait(0.05)
			expect(ClientState.isReady).toBe(true)
			expect(ClientState.state.coins).toBe(state.coins)
			HUD.tick()
		end)

		it("opens and refreshes every window", function()
			for _, key in { "Shop", "Critters", "Quests", "Rebirth", "Teleport", "Store", "Settings" } do
				WindowManager.open(key)
				expect(WindowManager.isOpen(key)).toBe(true)
				WindowManager.refresh(state)
			end
			WindowManager.close()
			expect(WindowManager.isOpen()).toBe(false)
		end)

		it("sends actions when buttons are pressed", function()
			env.requests = {}
			WindowManager.open("Shop")
			for _, d in guis.windows:GetDescendants() do
				if d.ClassName == "TextButton" and d.Name == "Face" then
					d.Activated:Fire()
				end
			end
			WindowManager.close()
			local sawBuy = false
			for _, r in env.requests do
				if r.action == "BuyUpgrade" then
					sawBuy = true
				end
			end
			expect(sawBuy).toBe(true)
		end)

		it("prompts real purchases only for configured products", function()
			env.marketplace.prompts = {}
			WindowManager.open("Store")
			for _, d in guis.windows:GetDescendants() do
				if d.ClassName == "TextButton" and d.Name == "Face" then
					d.Activated:Fire()
				end
			end
			WindowManager.close()
			expect(#env.marketplace.prompts).toBe(0) -- all ids are 0 until configured
		end)
	end)

	describe("debris renderer", function()
		it("builds zone visuals and applies deltas", function()
			DebrisRenderer._buildZone(1)
			task.wait(0.1)
			local folder = env.workspace:FindFirstChild("DebrisVisuals")
			local zoneFolder = folder:FindFirstChild("Zone1")
			local parts = #zoneFolder:GetChildren()
			print(string.format("      debris parts for zone 1: %d", parts))
			expect(parts).toBeGreaterThan(400)
			expect(DebrisRenderer.cleanFraction(1)).toBe(0)
			local mask = ZoneLayout.mask(1)
			local cells = {}
			local index = 0
			while #cells < 2 do
				if not mask[index] then
					table.insert(cells, index)
				end
				index += 1
			end
			local dirty = { [1] = { [cells[1]] = true, [cells[2]] = true } }
			local delta = NetCodec.encodeDirty(dirty, function()
				return 0
			end)
			env.remotes.DebrisDelta.OnClientEvent:Fire(delta)
			expect(DebrisRenderer.cleanFraction(1)).toBeGreaterThan(0)
		end)

		it("rebuilds golden waves and switches graphics modes", function()
			local originX, originZ, cols, rows = ZoneLayout.debrisArea(1)
			local grid = DebrisGrid.new({ cols = cols, rows = rows, cellSize = GameConfig.CellSize, originX = originX, originZ = originZ, cellMax = GameConfig.CellMax, mask = ZoneLayout.mask(1) })
			grid:fill()
			env.remotes.ZoneWave.OnClientEvent:Fire(1, 2, true, grid:snapshot())
			expect(DebrisRenderer.isGolden(1)).toBe(true)
			DebrisRenderer.setLowGraphics(true)
			DebrisRenderer._buildZone(1)
			task.wait(0.1)
			local zoneFolder = env.workspace:FindFirstChild("DebrisVisuals"):FindFirstChild("Zone1")
			expect(#zoneFolder:GetChildren()).toBeGreaterThan(200)
		end)

		it("finds the nearest debris for the tutorial beam", function()
			local cx = ZoneLayout.center(1)
			expect(DebrisRenderer.nearestDebris(cx, 30, 1)).toBeTruthy()
		end)
	end)

	describe("effects", function()
		it("plays every server effect without errors", function()
			local effects = {
				{ "sell", { coins = 1234, units = 40 } },
				{ "critter", { id = "fox", isNew = true } },
				{ "zoneClear", { zoneId = 1, bonus = 500 } },
				{ "purchase", { text = "Bought!", robux = true } },
				{ "unlock", { zoneId = 2 } },
				{ "rebirth", { rebirths = 1 } },
				{ "reward", { text = "+5 coins" } },
				{ "bagFull", {} },
				{ "questDone", { count = 1 } },
				{ "storm", { by = "Tester", endsAt = 0 } },
				{ "golden", { id = "squirrel" } },
			}
			for _, e in effects do
				ClientState.Effect:Fire(e[1], e[2])
			end
			ClientState.Notify:Fire("error", "Test error")
			ClientState.Notify:Fire("success", "Test success")
			expect(#guis.fx:GetDescendants()).toBeGreaterThan(50)
		end)
	end)

	describe("world views", function()
		it("builds critter followers for equipped critters", function()
			CritterFollowers._rebuild(env.player)
			env.player:SetAttribute("Equipped", "golden:squirrel,fox")
			CritterFollowers._rebuild(env.player)
			local folder = env.workspace:FindFirstChild("CritterFollowers")
			expect(#folder:GetChildren()).toBe(2)
		end)
	end)
end
