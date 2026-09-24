--!strict
-- Always-visible HUD: coins, bag meter, zone cleanliness, storm banner, boost timers and the menu
-- buttons (left side, reachable by thumb on phones; hotkeys on PC).

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local Economy = require(Shared.Logic.Economy)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Components)
local WindowManager = require(script.Parent.WindowManager)
local Responsive = require(script.Parent.Responsive)

local HUD = {}

local Colors = Theme.Colors
local player = Players.LocalPlayer

local coinsLabel: TextLabel
local coinsPill: Frame
local bagBar: C.ProgressBar
local zoneBar: C.ProgressBar
local goldenBadge: TextLabel
local stormBanner: Frame
local stormLabel: TextLabel
local squadChip: Frame
local squadLabel: TextLabel
local boostsRow: Frame
local badges: { [string]: TextLabel } = {}
local menuButtons: { [string]: C.Button } = {}

local displayedCoins = 0
local targetCoins = 0
local lastBagFull = false
local cleanFractionFn: (number) -> number = function(_zoneId: number)
	return 0
end
local isGoldenFn: (number) -> boolean = function(_zoneId: number)
	return false
end

HUD.MenuItems = {
	{ key = "Shop", emoji = "🛒", label = "Shop", hotkey = "B", color = Colors.Accent, dark = Colors.AccentDark },
	{ key = "Critters", emoji = "🐿️", label = "Critters", hotkey = "C", color = Colors.Green, dark = Colors.GreenDark },
	{ key = "Quests", emoji = "📜", label = "Quests", hotkey = "Q", color = Colors.Blue, dark = Colors.BlueDark },
	{ key = "Rebirth", emoji = "♻️", label = "Rebirth", hotkey = "R", color = Colors.Purple, dark = Colors.PurpleDark },
	{ key = "Teleport", emoji = "🗺️", label = "Travel", hotkey = "T", color = Color3.fromRGB(80, 190, 200), dark = Color3.fromRGB(50, 140, 150) },
	{ key = "Store", emoji = "💎", label = "Store", hotkey = "G", color = Colors.Gold, dark = Colors.GoldDark },
}

function HUD.setDebrisQueries(cleanFraction: (number) -> number, isGolden: (number) -> boolean)
	cleanFractionFn = cleanFraction
	isGoldenFn = isGolden
end

function HUD.mount(gui: ScreenGui)
	-- Coins
	coinsPill = C.card({
		Name = "Coins",
		Size = UDim2.fromOffset(250, 58),
		Position = UDim2.new(0.5, -8, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Colors.Gold,
		CornerRadius = 29,
		Parent = gui,
	})
	C.gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 210, 170)).Parent = coinsPill
	coinsLabel = C.outlined({
		Name = "Amount",
		Text = "🪙 0",
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = coinsPill,
	})

	-- Bag
	bagBar = C.progress({
		Name = "Bag",
		Size = UDim2.fromOffset(250, 58),
		Position = UDim2.new(0.5, 8, 0, 8),
		Color = Colors.Green,
		StrokeThickness = 3,
		Parent = gui,
	})

	-- Zone cleanliness
	zoneBar = C.progress({
		Name = "Zone",
		Size = UDim2.fromOffset(420, 32),
		Position = UDim2.new(0.5, 0, 0, 76),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Colors.Blue,
		Parent = gui,
	})
	goldenBadge = C.outlined({
		Name = "Golden",
		Text = "✨ GOLDEN x3",
		Size = UDim2.fromOffset(130, 26),
		Position = UDim2.new(1, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.Gold,
		Visible = false,
		Parent = zoneBar.root,
	})
	C.round().Parent = goldenBadge
	C.stroke(Colors.Stroke, 2).Parent = goldenBadge

	-- Squad bonus chip (left of the zone bar) + invite button
	squadChip = C.card({
		Name = "Squad",
		Size = UDim2.fromOffset(170, 32),
		Position = UDim2.new(0.5, -218, 0, 76),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Colors.Green,
		CornerRadius = 16,
		Visible = false,
		Parent = gui,
	})
	squadLabel = C.outlined({
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = squadChip,
	})
	C.button({
		Name = "Invite",
		Text = "👋 Invite",
		Size = UDim2.fromOffset(120, 50),
		Position = UDim2.new(0.5, 270, 0, 10),
		AnchorPoint = Vector2.new(0, 0),
		Color = Colors.Blue,
		DarkColor = Colors.BlueDark,
		Parent = gui,
		OnClick = function()
			task.spawn(function()
				local ok, canInvite = pcall(function()
					return SocialService:CanSendGameInviteAsync(player)
				end)
				if ok and canInvite then
					pcall(function()
						SocialService:PromptGameInvite(player)
					end)
				end
			end)
		end,
	})

	-- Storm banner
	stormBanner = C.card({
		Name = "Storm",
		Size = UDim2.fromOffset(460, 34),
		Position = UDim2.new(0.5, 0, 0, 114),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Colors.Purple,
		Visible = false,
		Parent = gui,
	})
	stormLabel = C.outlined({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = stormBanner,
	})

	-- Boost timers (bottom center, clear of thumbstick and jump button)
	boostsRow = C.new("Frame", {
		Name = "Boosts",
		Size = UDim2.fromOffset(520, 40),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { C.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })

	-- Menu buttons
	local menu = C.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(84, 470),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { C.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for index, item in HUD.MenuItems do
		local button = C.button({
			Name = item.key,
			Text = "",
			Size = UDim2.fromOffset(76, 62),
			Color = item.color,
			DarkColor = item.dark,
			LayoutOrder = index,
			Parent = menu,
			OnClick = function()
				WindowManager.toggle(item.key)
			end,
		})
		C.label({
			Text = item.emoji,
			Size = UDim2.new(1, 0, 0.62, 0),
			Position = UDim2.fromScale(0.5, 0.04),
			AnchorPoint = Vector2.new(0.5, 0),
			Parent = button.button,
		})
		C.outlined({
			Text = if Responsive.isTouch then item.label else item.label .. " (" .. item.hotkey .. ")",
			Size = UDim2.new(1, -6, 0.3, 0),
			Position = UDim2.fromScale(0.5, 0.95),
			AnchorPoint = Vector2.new(0.5, 1),
			StrokeThickness = 1.5,
			Parent = button.button,
		})
		badges[item.key] = C.badge(button.root)
		menuButtons[item.key] = button
	end
	local settings = C.button({
		Name = "Settings",
		Text = "⚙️",
		Size = UDim2.fromOffset(52, 44),
		Color = Colors.Grey,
		DarkColor = Colors.GreyDark,
		LayoutOrder = 100,
		Parent = menu,
		OnClick = function()
			WindowManager.toggle("Settings")
		end,
	})
	menuButtons.Settings = settings
end

function HUD.menuButton(key: string): C.Button?
	return menuButtons[key]
end

local function setBadge(key: string, count: number)
	local badge = badges[key]
	if badge then
		badge.Visible = count > 0
		badge.Text = if count > 9 then "9+" else tostring(count)
	end
end

local function boostChip(text: string, color: Color3, order: number)
	local chip = C.card({
		Size = UDim2.fromOffset(170, 36),
		BackgroundColor3 = color,
		LayoutOrder = order,
		CornerRadius = 18,
	})
	C.outlined({
		Text = text,
		Size = UDim2.new(1, -14, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = chip,
	})
	chip.Parent = boostsRow
end

-- Called whenever the replicated state changes.
function HUD.refresh(state: { [string]: any })
	-- badges
	local claimable = 0
	for _, quest in state.quests.list do
		if not quest.claimed and quest.progress >= quest.target then
			claimable += 1
		end
	end
	if state.streak.claimedDay ~= QuestLogic.dayIndex(Workspace:GetServerTimeNow()) then
		claimable += 1
	end
	setBadge("Quests", claimable)
	setBadge("Rebirth", if state.coins >= Economy.rebirthCost(state.rebirths) then 1 else 0)
	local goldenReady = 0
	for _, owned in state.critters do
		if owned.count >= 5 then
			goldenReady += 1
		end
	end
	setBadge("Critters", goldenReady)

	-- boosts
	for _, child in boostsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if state.boosts.coins2x > 0 then
		boostChip("⚡ 2x Coins " .. Format.time(state.boosts.coins2x), Colors.Gold, 1)
	end
	if state.boosts.collect2x > 0 then
		boostChip("🌪️ Suction " .. Format.time(state.boosts.collect2x), Colors.Blue, 2)
	end
end

function HUD.flashCoins(amount: number)
	local pop = C.outlined({
		Text = "+" .. Format.abbreviate(amount) .. " 🪙",
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.new(0.5, 0, 1, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor3 = Colors.Gold,
		ZIndex = 5,
		Parent = coinsPill,
	})
	TweenService:Create(pop, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, 60),
		TextTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		pop:Destroy()
	end)
	C.pop(coinsPill)
end

-- 10 Hz update for fast-changing values read from attributes and the local debris mirror.
function HUD.tick()
	local coins = (player:GetAttribute("Coins") :: number?) or 0
	targetCoins = coins
	if math.abs(displayedCoins - targetCoins) < 1 then
		displayedCoins = targetCoins
	else
		displayedCoins += (targetCoins - displayedCoins) * 0.35
	end
	coinsLabel.Text = "🪙 " .. Format.abbreviate(displayedCoins)

	local units = (player:GetAttribute("BagUnits") :: number?) or 0
	local capacity = (player:GetAttribute("BagCapacity") :: number?) or 1
	local fill = units / math.max(capacity, 1)
	local full = units >= capacity
	bagBar.set(fill, if full then "🎒 FULL! Sell at 💰" else string.format("🎒 %s / %s", Format.abbreviate(units), Format.abbreviate(capacity)))
	bagBar.fill.BackgroundColor3 = if full then Colors.Red elseif fill > 0.75 then Colors.Accent else Colors.Green
	if full and not lastBagFull then
		C.pop(bagBar.root)
	end
	lastBagFull = full

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local zoneId = root and ZoneLayout.zoneAt(root.Position.X, root.Position.Z)
	if zoneId and zoneId >= 1 then
		local zone = Zones[zoneId]
		zoneBar.root.Visible = true
		zoneBar.set(cleanFractionFn(zoneId), string.format("%s %s · %s clean", zone.emoji, zone.name, Format.percent(cleanFractionFn(zoneId))))
		goldenBadge.Visible = isGoldenFn(zoneId)
	elseif zoneId == 0 then
		zoneBar.root.Visible = true
		zoneBar.set(1, "🏡 Maple Hollow — shops & quests")
		goldenBadge.Visible = false
	else
		zoneBar.root.Visible = false
	end

	-- squad bonus preview (the server computes the real bonus the same way)
	local squad = 0
	if root and zoneId and zoneId >= 1 then
		local r2 = GameConfig.SquadRadius * GameConfig.SquadRadius
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if otherRoot then
					local d = otherRoot.Position - root.Position
					if d.X * d.X + d.Z * d.Z <= r2 and ZoneLayout.zoneAt(otherRoot.Position.X, otherRoot.Position.Z) == zoneId then
						squad += 1
					end
				end
			end
		end
	end
	local bonus = math.min(GameConfig.SquadBonusMax, squad * GameConfig.SquadBonusPerPlayer)
	squadChip.Visible = bonus > 0
	if bonus > 0 then
		squadLabel.Text = string.format("👥 Squad +%d%%", math.floor(bonus * 100 + 0.5))
	end

	local stormEnds = (Workspace:GetAttribute("StormEndsAt") :: number?) or 0
	local remaining = stormEnds - Workspace:GetServerTimeNow()
	if remaining > 0 then
		stormBanner.Visible = true
		stormLabel.Text = string.format("🌟 GOLDEN STORM by %s · 2x coins · %s", tostring(Workspace:GetAttribute("StormBy") or "?"), Format.time(remaining))
	else
		stormBanner.Visible = false
	end
end

return HUD
