--!strict
-- Juice: reacts to server Effect events with sounds, popups, confetti, banners and particles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Critters = require(Shared.Config.Critters)
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local CritterModels = require(Shared.World.CritterModels)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local HUD = require(UI.HUD)
local Notifications = require(UI.Notifications)
local Audio = require(script.Parent.Audio)
local ClientState = require(script.Parent.ClientState)

local Effects = {}

local Colors = Theme.Colors
local player = Players.LocalPlayer
local gui: ScreenGui
local random = Random.new()

local CONFETTI_COLORS = { Colors.Accent, Colors.Gold, Colors.Green, Colors.Blue, Colors.Purple, Colors.Red }

function Effects.confetti(amount: number?)
	for _ = 1, amount or 40 do
		local piece = C.new("Frame", {
			Size = UDim2.fromOffset(random:NextInteger(8, 14), random:NextInteger(12, 20)),
			Position = UDim2.new(random:NextNumber(0.05, 0.95), 0, -0.05, 0),
			BackgroundColor3 = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			Rotation = random:NextNumber(0, 360),
			ZIndex = 20,
			Parent = gui,
		})
		local duration = random:NextNumber(1.4, 2.4)
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + random:NextNumber(-0.15, 0.15), 0, 1.05, 0),
			Rotation = piece.Rotation + random:NextNumber(-540, 540),
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

function Effects.banner(title: string, subtitle: string?, color: Color3?)
	local root = C.new("Frame", {
		Size = UDim2.fromOffset(700, 130),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Parent = gui,
	})
	local titleLabel = C.outlined({
		Text = title,
		Size = UDim2.new(1, 0, 0, 80),
		TextColor3 = color or Colors.Gold,
		StrokeThickness = 4,
		ZIndex = 15,
		Parent = root,
	})
	local subLabel = C.outlined({
		Text = subtitle or "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 84),
		ZIndex = 15,
		Parent = root,
	})
	C.pop(root)
	task.delay(2.4, function()
		local info = TweenInfo.new(0.5)
		TweenService:Create(titleLabel, info, { TextTransparency = 1 }):Play()
		TweenService:Create(subLabel, info, { TextTransparency = 1 }):Play()
		for _, s in root:GetDescendants() do
			if s:IsA("UIStroke") then
				TweenService:Create(s, info, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.55)
		root:Destroy()
	end)
end

local function critterPopup(critterId: string, isNew: boolean)
	local critter = Critters.ById[critterId]
	if not critter then
		return
	end
	local rarity = Critters.Rarities[critter.rarity]
	local card = C.card({
		Size = UDim2.fromOffset(300, 330),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Colors.Background,
		StrokeColor = rarity.color,
		ZIndex = 12,
		Parent = gui,
	})
	C.outlined({
		Text = if isNew then "✨ NEW CRITTER! ✨" else "Critter found!",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 10),
		TextColor3 = rarity.color,
		ZIndex = 13,
		Parent = card,
	})
	local vp = C.new("ViewportFrame", {
		Size = UDim2.new(1, -40, 0, 170),
		Position = UDim2.fromOffset(20, 54),
		BackgroundColor3 = Color3.fromRGB(240, 232, 214),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 250, 240),
		ZIndex = 13,
		Parent = card,
	}, { C.corner(12) })
	local model = CritterModels.build(critterId, false, vp, CFrame.Angles(0, math.rad(20), 0), 1)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.4, -7.5), Vector3.new(0, 1.5, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	C.label({ Text = critter.name, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 232), ZIndex = 13, Parent = card })
	local bonus = critter.value
	local bonusText = if critter.bonus == "radius" or critter.bonus == "speed"
		then string.format("+%s %s", tostring(bonus), Critters.BonusLabels[critter.bonus])
		else string.format("+%d%% %s", math.floor(bonus * 100 + 0.5), Critters.BonusLabels[critter.bonus])
	C.label({
		Text = critter.rarity .. " · " .. bonusText,
		Font = Theme.Fonts.Bold,
		TextColor3 = rarity.color,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 270),
		ZIndex = 13,
		Parent = card,
	})
	C.pop(card)
	if model then
		task.spawn(function()
			local angle = 20
			while card.Parent do
				angle += 2
				model:PivotTo(CFrame.Angles(0, math.rad(angle), 0))
				task.wait(1 / 30)
			end
		end)
	end
	task.delay(3.2, function()
		card:Destroy()
	end)
end

local function coinBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local attachment = root:FindFirstChild("SweepBurst") :: Attachment?
	local emitter: ParticleEmitter
	if not attachment then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = "SweepBurst"
		newAttachment.Parent = root
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Coins"
		emitter.Enabled = false
		emitter.Color = ColorSequence.new(Colors.Gold)
		emitter.LightEmission = 0.4
		emitter.Size = NumberSequence.new(0.5, 0.2)
		emitter.Speed = NumberRange.new(10, 16)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Acceleration = Vector3.new(0, -30, 0)
		emitter.Lifetime = NumberRange.new(0.6, 0.9)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Parent = newAttachment
	else
		emitter = attachment:FindFirstChild("Coins") :: ParticleEmitter
	end
	if emitter then
		emitter:Emit(18)
	end
end

local handlers: { [string]: (payload: any) -> () } = {
	sell = function(payload)
		HUD.flashCoins(payload.coins)
		Audio.play("Sell")
		coinBurst()
	end,
	critter = function(payload)
		Audio.play("CritterFound")
		critterPopup(payload.id, payload.isNew)
	end,
	zoneClear = function(payload)
		local zone = Zones[payload.zoneId]
		Audio.play("ZoneClear")
		Effects.confetti(50)
		Effects.banner("SPARKLING CLEAN!", string.format("%s %s · +%s 🪙 teamwork bonus", zone.emoji, zone.name, Format.abbreviate(payload.bonus)), Colors.Green)
	end,
	purchase = function(payload)
		Audio.play("Purchase")
		Notifications.show("success", payload.text)
		if payload.robux then
			Effects.confetti(40)
		end
	end,
	unlock = function(payload)
		local zone = Zones[payload.zoneId]
		Audio.play("ZoneClear")
		Effects.confetti(60)
		Effects.banner("NEW ZONE UNLOCKED!", zone.emoji .. " " .. zone.name, zone.theme.accent)
	end,
	rebirth = function(payload)
		Audio.play("ZoneClear")
		Effects.confetti(80)
		Effects.banner("REBIRTH #" .. payload.rebirths .. "!", "Permanent coin bonus increased! ♻️", Colors.Purple)
	end,
	reward = function(payload)
		Audio.play("Purchase")
		Notifications.show("reward", payload.text)
	end,
	bagFull = function()
		Notifications.show("error", "🎒 Bag full! Walk onto a 💰 SELL pad", 2.5)
	end,
	questDone = function()
		Audio.play("Purchase")
	end,
	storm = function(payload)
		Audio.play("ZoneClear")
		Effects.confetti(60)
		Effects.banner("🌟 GOLDEN STORM!", payload.by .. " made it rain — 2x coins for EVERYONE!", Colors.Gold)
	end,
	golden = function(payload)
		local critter = Critters.ById[payload.id]
		Effects.confetti(40)
		Notifications.show("reward", "✨ Golden " .. (if critter then critter.name else "critter") .. "! x" .. GameConfig.GoldenBonusMultiplier .. " bonus")
	end,
}

function Effects.mount(screen: ScreenGui)
	gui = screen
end

function Effects:Init()
	ClientState.Effect:Connect(function(kind: string, payload: any)
		local handler = handlers[kind]
		if handler then
			handler(payload or {})
		end
	end)
	ClientState.Notify:Connect(function(kind: string, text: string)
		Notifications.show(kind, text)
		if kind == "error" then
			Audio.play("Error")
		end
	end)
end

return Effects
