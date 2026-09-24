--!strict
-- First-session guidance: a hint card + a glowing guide beam pointing at the next objective.
-- Steps are advanced by the server from real gameplay events (collect -> sell -> upgrade -> unlock).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Zones = require(Shared.Config.Zones)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local HUD = require(UI.HUD)
local ClientState = require(script.Parent.ClientState)
local DebrisRenderer = require(script.Parent.DebrisRenderer)

local Tutorial = {}

local Colors = Theme.Colors
local player = Players.LocalPlayer
local DONE = 5

local card: Frame
local text: TextLabel
local step = DONE
local beam: Beam? = nil
local targetPart: Part
local targetAttachment: Attachment
local pulseTween: Tween? = nil

local STEP_TEXT = {
	[1] = "🍂 Walk into the leaves to vacuum them up!",
	[2] = "💰 Bag has leaves! Walk onto a green SELL pad",
	[3] = "🛒 Open the Shop (left) and buy an upgrade!",
	[4] = "🎃 Save up and unlock Pumpkin Patch Park at its gate (%s 🪙)",
}

local function ensureBeam(): Beam?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local rootAttachment = root:FindFirstChild("TutorialAttachment") :: Attachment?
	if not rootAttachment then
		local a = Instance.new("Attachment")
		a.Name = "TutorialAttachment"
		a.Position = Vector3.new(0, -2, 0)
		a.Parent = root
		rootAttachment = a
	end
	if beam and beam.Attachment0 == rootAttachment then
		return beam
	end
	if beam then
		beam:Destroy()
	end
	local b = Instance.new("Beam")
	b.Attachment0 = rootAttachment
	b.Attachment1 = targetAttachment
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.FaceCamera = true
	b.Segments = 12
	b.LightEmission = 0.8
	b.Color = ColorSequence.new(Colors.Gold)
	b.Transparency = NumberSequence.new(0.15, 0.5)
	b.TextureSpeed = 1.5
	b.Parent = targetPart
	beam = b
	return b
end

local function targetFor(currentStep: number): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local p = root.Position
	local zoneId = ZoneLayout.zoneAt(p.X, p.Z)
	if currentStep == 1 then
		if zoneId and zoneId >= 1 then
			return DebrisRenderer.nearestDebris(p.X, p.Z, zoneId)
		end
		local x, z = ZoneLayout.spawnPoint(1)
		return Vector3.new(x + 10, 1, z)
	elseif currentStep == 2 then
		local best, bestD = nil, math.huge
		local searchZone = if zoneId and zoneId >= 1 then zoneId else 1
		for _, pad in ZoneLayout.sellPads(searchZone) do
			local d = (pad.x - p.X) ^ 2 + (pad.z - p.Z) ^ 2
			if d < bestD then
				best, bestD = Vector3.new(pad.x, 1, pad.z), d
			end
		end
		return best
	elseif currentStep == 4 then
		local x, z = ZoneLayout.gatePosition(2)
		return Vector3.new(x, 1, z)
	end
	return nil
end

local function pulseShop(on: boolean)
	local button = HUD.menuButton("Shop")
	if not button then
		return
	end
	if pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
	end
	local scale = button.root:FindFirstChild("PulseScale") :: UIScale?
	if not scale then
		local s = Instance.new("UIScale")
		s.Name = "PulseScale"
		s.Parent = button.root
		scale = s
	end
	if not scale then
		return
	end
	if on then
		scale.Scale = 1
		local tween = TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.15 })
		tween:Play()
		pulseTween = tween
	else
		scale.Scale = 1
	end
end

local function apply(state: { [string]: any })
	step = state.tutorialStep or DONE
	card.Visible = step < DONE
	if step < DONE then
		local template = STEP_TEXT[step] or ""
		text.Text = if step == 4 then string.format(template, Format.abbreviate(Zones[2].unlockCost)) else template
	end
	pulseShop(step == 3)
	if step >= DONE and beam then
		beam:Destroy()
		beam = nil
	end
end

function Tutorial.mount(gui: ScreenGui)
	card = C.card({
		Name = "Tutorial",
		Size = UDim2.fromOffset(560, 58),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Colors.Accent,
		Visible = false,
		Parent = gui,
	})
	C.gradient(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)).Parent = card
	text = C.outlined({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = card,
	})
end

function Tutorial:Init()
	targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.new(0.2, 0.2, 0.2)
	targetPart.Parent = Workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart
	ClientState.Changed:Connect(apply)
end

function Tutorial:Start()
	task.spawn(function()
		while true do
			if step < DONE then
				local target = targetFor(step)
				if target then
					targetPart.CFrame = CFrame.new(target)
					local b = ensureBeam()
					if b then
						b.Enabled = true
					end
				elseif beam then
					beam.Enabled = false
				end
			end
			task.wait(0.5)
		end
	end)
end

return Tutorial
