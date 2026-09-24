--!nocheck
-- Builds the REAL client UI (HUD, toasts, tutorial and each window) for several device sizes and
-- exports the GUI trees as JSON for the HTML layout renderer (ui.html / render_ui.js).
--   lune run tools/preview/export_ui.luau
-- Output: tools/preview/ui/<device>_<screen>.json

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = require("../../tests/harness")
local ClientEnv = require("../../tests/clientenv")

local DEVICES = {
	{ name = "phone", size = roblox.Vector2.new(844, 390), touch = true, inset = 0 },
	{ name = "tablet", size = roblox.Vector2.new(1180, 820), touch = true, inset = 0 },
	{ name = "pc", size = roblox.Vector2.new(1920, 1080), touch = false, inset = 58 },
}
local SCREENS = { "HUD", "Shop", "Critters", "Quests", "Rebirth", "Teleport", "Store", "Settings" }

---------------------------------------------------------------------------------------------------
-- GUI tree export
---------------------------------------------------------------------------------------------------

local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end
local function color(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function enumName(e)
	return e and e.Name or nil
end

local GUI_OBJECTS = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	ImageLabel = true,
	ImageButton = true,
}

local function exportNode(inst)
	local class = inst.ClassName
	local node = { c = class, n = inst.Name, k = {}, m = {} }
	if class == "ScreenGui" then
		node.p = { Enabled = inst.Enabled, DisplayOrder = inst.DisplayOrder }
	elseif GUI_OBJECTS[class] then
		local p = {
			Size = udim2(inst.Size),
			Position = udim2(inst.Position),
			Anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y },
			Visible = inst.Visible,
			Bg = color(inst.BackgroundColor3),
			BgT = inst.BackgroundTransparency,
			Z = inst.ZIndex,
			Order = inst.LayoutOrder,
			Rot = inst.Rotation,
			Auto = enumName(inst.AutomaticSize),
		}
		if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
			p.Text = inst.Text
			p.TextColor = color(inst.TextColor3)
			p.TextT = inst.TextTransparency
			p.Scaled = inst.TextScaled
			p.TextSize = inst.TextSize
			p.Wrapped = inst.TextWrapped
			local ok, face = pcall(function()
				return inst.FontFace
			end)
			local family = if ok and face then tostring(face.Family) else ""
			local weight = if ok and face then tostring(face.Weight) else ""
			p.Font = (string.match(family, "families/([%w]+)%.json") or "Gotham") .. (if string.find(weight, "Bold") then "Bold" else "")
			p.XAlign = enumName(inst.TextXAlignment)
			p.YAlign = enumName(inst.TextYAlignment)
			if class == "TextBox" then
				p.Placeholder = inst.PlaceholderText
			end
		end
		if class == "ScrollingFrame" then
			p.Scroll = true
		end
		node.p = p
	else
		-- modifiers
		local m = { c = class }
		if class == "UICorner" then
			m.Radius = { inst.CornerRadius.Scale, inst.CornerRadius.Offset }
		elseif class == "UIStroke" then
			m.Color = color(inst.Color)
			m.Thickness = inst.Thickness
			m.T = inst.Transparency
			m.Mode = enumName(inst.ApplyStrokeMode)
		elseif class == "UIListLayout" then
			m.Dir = enumName(inst.FillDirection)
			m.Padding = { inst.Padding.Scale, inst.Padding.Offset }
			m.H = enumName(inst.HorizontalAlignment)
			m.V = enumName(inst.VerticalAlignment)
		elseif class == "UIGridLayout" then
			m.Cell = udim2(inst.CellSize)
			m.Pad = udim2(inst.CellPadding)
			m.H = enumName(inst.HorizontalAlignment)
		elseif class == "UIPadding" then
			m.T = { inst.PaddingTop.Scale, inst.PaddingTop.Offset }
			m.B = { inst.PaddingBottom.Scale, inst.PaddingBottom.Offset }
			m.L = { inst.PaddingLeft.Scale, inst.PaddingLeft.Offset }
			m.R = { inst.PaddingRight.Scale, inst.PaddingRight.Offset }
		elseif class == "UIScale" then
			m.Scale = inst.Scale
		elseif class == "UISizeConstraint" then
			m.Max = { inst.MaxSize.X, inst.MaxSize.Y }
		elseif class == "UIGradient" then
			local kp = inst.Color.Keypoints
			m.From = color(kp[1].Value)
			m.To = color(kp[#kp].Value)
			m.Rot = inst.Rotation
		else
			return nil
		end
		return m
	end
	for _, child in inst:GetChildren() do
		local exported = exportNode(child)
		if exported then
			if exported.k then
				table.insert(node.k, exported)
			else
				table.insert(node.m, exported)
			end
		end
	end
	return node
end

---------------------------------------------------------------------------------------------------
-- Build the UI per device
---------------------------------------------------------------------------------------------------

fs.writeDir("tools/preview/ui")

for _, device in DEVICES do
	Harness.reset()
	ClientEnv.viewport = device.size
	ClientEnv.touch = device.touch
	local env = ClientEnv.install(Harness)
	local camera = roblox.Instance.new("Camera")
	camera.Parent = ClientEnv.unwrap(env.workspace)
	ClientEnv.unwrap(env.workspace).CurrentCamera = camera

	local R = function(path)
		return Harness.requirePath(path)
	end
	local Shared = "ReplicatedStorage.Shared."
	local Client = "StarterPlayer.StarterPlayerScripts.Client."
	local DataSchema = R(Shared .. "Logic.DataSchema")
	local Stats = R(Shared .. "Logic.Stats")
	local QuestLogic = R(Shared .. "Logic.QuestLogic")
	local ZoneLayout = R(Shared .. "Logic.ZoneLayout")
	local ClientState = R(Client .. "Controllers.ClientState")
	local DebrisRenderer = R(Client .. "Controllers.DebrisRenderer")
	local Tutorial = R(Client .. "Controllers.Tutorial")
	local Responsive = R(Client .. "UI.Responsive")
	local HUD = R(Client .. "UI.HUD")
	local Notifications = R(Client .. "UI.Notifications")
	local WindowManager = R(Client .. "UI.WindowManager")

	-- a mid-game player with a bit of everything, so every widget has content
	local profile = DataSchema.new(os.time())
	profile.coins = 1_234_567
	profile.maxZone = 4
	profile.vacuumTier = 6
	profile.bagTier = 5
	profile.bootsTier = 4
	profile.rebirths = 1
	profile.rebirthTokens = 2
	profile.critters = { squirrel = { count = 6, golden = 1 }, fox = { count = 1, golden = 0 }, crow = { count = 2, golden = 0 }, owl = { count = 1, golden = 0 } }
	profile.discovered = { squirrel = true, fox = true, crow = true, owl = true }
	profile.equipped = { "golden:squirrel", "fox", "crow" }
	profile.boosts.coins2x = 754
	profile.tutorialStep = 5
	QuestLogic.ensureToday(profile, os.time(), 7)
	profile.quests.list[1].progress = profile.quests.list[1].target
	profile.quests.list[2].progress = math.floor(profile.quests.list[2].target / 2)
	QuestLogic.updateStreak(profile, os.time())
	local state = DataSchema.clientView(profile)
	state.derived = Stats.compute(profile)
	state.passes = { VIP = true }
	state.storm = { endsAt = 0, by = "" }

	ClientState:Init()
	DebrisRenderer:Init()
	Tutorial:Init()
	Responsive.start()
	local hud = Responsive.screen("SweepHUD", 1, env.playerGui)
	local windows = Responsive.screen("SweepWindows", 5, env.playerGui)
	local fx = Responsive.screen("SweepFX", 10, env.playerGui)
	HUD.mount(hud)
	HUD.setDebrisQueries(function()
		return 0.64
	end, function(zoneId)
		return zoneId == 1
	end)
	Tutorial.mount(hud)
	WindowManager.mount(windows)
	Notifications.mount(fx)
	local Windows = Harness.findPath("StarterPlayer.StarterPlayerScripts.Client.UI.Windows")
	local request = ClientState.request
	WindowManager.register(Harness.require(Windows.ShopWindow)(request))
	WindowManager.register(Harness.require(Windows.CrittersWindow)(request))
	WindowManager.register(Harness.require(Windows.QuestsWindow)(request))
	WindowManager.register(Harness.require(Windows.RebirthWindow)(request))
	WindowManager.register(Harness.require(Windows.TeleportWindow)(request, function() end))
	WindowManager.register(Harness.require(Windows.StoreWindow)())
	WindowManager.register(Harness.require(Windows.SettingsWindow)(request))
	HUD.refresh(state)
	WindowManager.refresh(state)

	-- character in zone 1 with a teammate nearby (squad chip) and a full-ish bag
	local Instance = ClientEnv.Instance
	local function makeCharacter(player, x, z)
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = roblox.CFrame.new(x, 3, z)
		root.Parent = character
		character.Parent = env.workspace
		player.Character = character
	end
	makeCharacter(env.player, ZoneLayout.center(1), 30)
	env.player:SetAttribute("Coins", profile.coins)
	env.player:SetAttribute("BagUnits", 420)
	env.player:SetAttribute("BagCapacity", 600)
	HUD.tick()
	HUD.tick()
	HUD.tick()
	Notifications.show("success", "📜 Quest complete! Claim your reward in Quests.", 30)

	for _, screen in SCREENS do
		if screen == "HUD" then
			WindowManager.close()
			Notifications.dock(false)
		else
			WindowManager.open(screen)
			WindowManager.refresh(state)
			Notifications.dock(true)
		end
		task.wait(0.05)
		local tree = { device = device.name, viewport = { device.size.X, device.size.Y }, inset = device.inset, guis = {} }
		for _, gui in { hud, windows, fx } do
			table.insert(tree.guis, exportNode(ClientEnv.unwrap(gui)))
		end
		fs.writeFile(string.format("tools/preview/ui/%s_%s.json", device.name, screen), serde.encode("json", tree))
	end
	print(string.format("exported UI for %s (%dx%d, UIScale %.2f)", device.name, device.size.X, device.size.Y, Responsive.compute()))
end
