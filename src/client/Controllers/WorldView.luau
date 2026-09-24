--!strict
-- Local presentation of the world:
--  * gates: unlocked gates become passable + invisible for this player only (the server still
--    enforces zone access), and only the next gate shows its unlock prompt
--  * zone ambience: atmosphere/color tint per zone + a title card when entering a zone
--  * gear: the bag on every character grows as it fills; vacuum sparkles while collecting
--  * weather: local snowfall above the player in snowy zones (Frosty Peaks, Snow Day event)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Zones = require(Shared.Config.Zones)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local EventLogic = require(Shared.Logic.EventLogic)
local Format = require(Shared.Util.Format)
local GearModels = require(Shared.World.GearModels)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local ClientState = require(script.Parent.ClientState)
local DebrisRenderer = require(script.Parent.DebrisRenderer)

local WorldView = {}

local player = Players.LocalPlayer
local maxZone = 1
local currentZone: number? = -99
local gui: ScreenGui
local titleCard: Frame?
local lowGraphics = false

---------------------------------------------------------------------------------------------------
-- Gates
---------------------------------------------------------------------------------------------------

local function styleGate(gate: BasePart)
	local zoneId = gate:GetAttribute("ZoneId")
	if type(zoneId) ~= "number" then
		return
	end
	local unlocked = zoneId <= maxZone
	gate.CanCollide = not unlocked
	gate.Transparency = if unlocked then 1 else 0
	for _, child in gate:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = not unlocked
			local label = child:FindFirstChildOfClass("TextLabel")
			if label and not unlocked then
				local zone = Zones[zoneId]
				label.Text = if zoneId == maxZone + 1
					then string.format("🔒 %s\n%s 🪙", zone.name, Format.abbreviate(zone.unlockCost))
					else string.format("🔒 %s\nUnlock %s first", zone.name, Zones[zoneId - 1].name)
			end
		elseif child:IsA("ProximityPrompt") then
			child.Enabled = not unlocked and zoneId == maxZone + 1
		end
	end
end

local function styleAllGates()
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		if gate:IsA("BasePart") then
			styleGate(gate)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Ambience
---------------------------------------------------------------------------------------------------

local defaultAtmosphere: { [string]: any }? = nil

local function applyAmbience(zoneId: number?)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not atmosphere then
		return
	end
	if not defaultAtmosphere then
		defaultAtmosphere = { Color = atmosphere.Color, Decay = atmosphere.Decay, Density = atmosphere.Density }
	end
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
	if zoneId and zoneId >= 1 then
		local theme = Zones[zoneId].theme
		local event = EventLogic.active(Workspace:GetServerTimeNow())
		local color, decay = theme.atmosphere, theme.decay
		if event and event.themeZone == zoneId then
			color, decay = event.atmosphere, event.decay
		end
		TweenService:Create(atmosphere, info, { Color = color, Decay = decay, Density = 0.3 }):Play()
		if correction then
			local golden = DebrisRenderer.isGolden(zoneId)
			TweenService:Create(correction, info, {
				TintColor = if golden then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(255, 251, 245),
			}):Play()
		end
	else
		local d = defaultAtmosphere :: { [string]: any }
		TweenService:Create(atmosphere, info, { Color = d.Color, Decay = d.Decay, Density = d.Density }):Play()
	end
end

local function showTitle(zoneId: number)
	if titleCard then
		titleCard:Destroy()
	end
	local text, sub
	if zoneId == 0 then
		text, sub = "🏡 Maple Hollow", "Shops · Quests · Rebirth"
	else
		local zone = Zones[zoneId]
		text = zone.emoji .. " " .. zone.name
		sub = string.format("%s · %s 🪙 each", zone.debrisName, Format.abbreviate(zone.unitValue))
	end
	local card = C.new("Frame", {
		Size = UDim2.fromOffset(600, 110),
		Position = UDim2.fromScale(0.5, 0.2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local title = C.outlined({ Text = text, Size = UDim2.new(1, 0, 0, 64), StrokeThickness = 3.5, Parent = card })
	local subtitle = C.outlined({ Text = sub, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 70), Parent = card })
	titleCard = card
	C.pop(card)
	task.delay(2.2, function()
		if card.Parent then
			local info = TweenInfo.new(0.6)
			TweenService:Create(title, info, { TextTransparency = 1 }):Play()
			TweenService:Create(subtitle, info, { TextTransparency = 1 }):Play()
			for _, s in card:GetDescendants() do
				if s:IsA("UIStroke") then
					TweenService:Create(s, info, { Transparency = 1 }):Play()
				end
			end
			task.wait(0.65)
			card:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Gear visuals
---------------------------------------------------------------------------------------------------

local function updateBag(target: Player)
	local character = target.Character
	local gear = character and character:FindFirstChild("SweepGear")
	local bag = gear and gear:FindFirstChild("Bag")
	local body = bag and bag:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local units = (target:GetAttribute("BagUnits") :: number?) or 0
	local capacity = (target:GetAttribute("BagCapacity") :: number?) or 1
	local fill = math.clamp(units / math.max(capacity, 1), 0, 1)
	local base = GearModels.BagBaseSize
	body.Size = base * (0.7 + 0.55 * fill)
end

local function watchPlayer(target: Player)
	target:GetAttributeChangedSignal("BagUnits"):Connect(function()
		updateBag(target)
	end)
	target.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(child)
			if child.Name == "SweepGear" then
				task.defer(updateBag, target)
			end
		end)
	end)
end

local sparkleUntil = 0
local function sparkle()
	local character = player.Character
	local gear = character and character:FindFirstChild("SweepGear")
	local tip = gear and gear:FindFirstChild("Tip", true) :: BasePart?
	local attachment = tip and tip:FindFirstChild("NozzleAttachment") :: Attachment?
	if not attachment then
		return
	end
	local emitter = attachment:FindFirstChild("Suction") :: ParticleEmitter?
	if not emitter then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Suction"
		e.Rate = 30
		e.Lifetime = NumberRange.new(0.2, 0.35)
		e.Speed = NumberRange.new(3, 6)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Size = NumberSequence.new(0.35, 0)
		e.Color = ColorSequence.new(Theme.Colors.Gold)
		e.LightEmission = 0.6
		e.Parent = attachment
		emitter = e
	end
	sparkleUntil = os.clock() + 0.35
	if emitter then
		emitter.Enabled = true
		task.delay(0.4, function()
			if os.clock() >= sparkleUntil and emitter then
				emitter.Enabled = false
			end
		end)
	end
end

---------------------------------------------------------------------------------------------------

function WorldView.mount(screen: ScreenGui)
	gui = screen
end

function WorldView:Init()
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(function(gate)
		if gate:IsA("BasePart") then
			styleGate(gate)
		end
	end)
	ClientState.Changed:Connect(function(state)
		lowGraphics = state.settings ~= nil and state.settings.lowGraphics == true
		if state.maxZone ~= maxZone then
			maxZone = state.maxZone
			styleAllGates()
		end
	end)
	for _, target in Players:GetPlayers() do
		watchPlayer(target)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	DebrisRenderer.LocalCollected:Connect(sparkle)
	DebrisRenderer.WaveChanged:Connect(function(zoneId)
		if zoneId == currentZone then
			applyAmbience(zoneId)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Weather: one local emitter part that follows the player (never replicated, never collides)
---------------------------------------------------------------------------------------------------

local weatherPart: Part? = nil

local function snowEmitter(): ParticleEmitter
	local part = weatherPart
	if not part then
		local newPart = Instance.new("Part")
		newPart.Name = "Weather"
		newPart.Anchored = true
		newPart.CanCollide = false
		newPart.CanQuery = false
		newPart.CanTouch = false
		newPart.CastShadow = false
		newPart.Transparency = 1
		newPart.Size = Vector3.new(90, 1, 90)
		local snow = Instance.new("ParticleEmitter")
		snow.Name = "Snow"
		snow.EmissionDirection = Enum.NormalId.Bottom
		snow.Speed = NumberRange.new(5, 8)
		snow.Lifetime = NumberRange.new(5, 7)
		snow.SpreadAngle = Vector2.new(15, 15)
		snow.RotSpeed = NumberRange.new(-40, 40)
		snow.Size = NumberSequence.new(0.35, 0.25)
		snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		snow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		snow.Enabled = false
		snow.Parent = newPart
		newPart.Parent = Workspace.CurrentCamera or Workspace
		weatherPart = newPart
		part = newPart
	end
	return (part :: Part):FindFirstChild("Snow") :: ParticleEmitter
end

local function updateWeather(zoneId: number?, rootPosition: Vector3)
	local weather = if zoneId and zoneId >= 1 then EventLogic.weatherFor(zoneId, Workspace:GetServerTimeNow()) else nil
	if weather == "snow" then
		local snow = snowEmitter()
		snow.Rate = if lowGraphics then 25 else 60
		snow.Enabled = true
		local part = weatherPart :: Part
		part.CFrame = CFrame.new(rootPosition + Vector3.new(0, 28, 0))
	elseif weatherPart then
		(weatherPart:FindFirstChild("Snow") :: ParticleEmitter).Enabled = false
	end
end

local function zoneStep()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local zoneId = ZoneLayout.zoneAt(root.Position.X, root.Position.Z)
		if zoneId ~= currentZone and zoneId ~= nil then
			currentZone = zoneId
			applyAmbience(zoneId)
			showTitle(zoneId)
		end
		updateWeather(currentZone, root.Position)
	end
end
WorldView._zoneStep = zoneStep
WorldView._weatherPart = function(): Part?
	return weatherPart
end

function WorldView:Start()
	styleAllGates()
	task.spawn(function()
		while true do
			zoneStep()
			task.wait(0.3)
		end
	end)
end

return WorldView
