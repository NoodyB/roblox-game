--!strict
-- Branded loading screen (ReplicatedFirst runs before anything else replicates).
-- Shows the logo + tips until the game has loaded, then fades out.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIPS = {
	"Clean with friends for a squad bonus of up to +30% coins!",
	"Critters hide in the debris. Merge 5 into a Golden one!",
	"Clear a whole zone together to summon a Golden Gust!",
	"Daily quests refresh every day at midnight UTC.",
	"Rebirth for a permanent coin multiplier.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "SweepLoading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(255, 176, 96)
background.BorderSizePixel = 0
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(255, 196, 120), Color3.fromRGB(230, 110, 50))
gradient.Rotation = 90
gradient.Parent = background

local function label(text: string, y: number, height: number, size: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0.8, 0, 0, height)
	l.Position = UDim2.new(0.5, 0, y, 0)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = size == nil
	if size then
		l.TextSize = size
		l.TextWrapped = true
	end
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(74, 46, 31)
	stroke.Parent = l
	l.Parent = background
	return l
end

local title = label("🍂 SWEEP SQUAD 🍂", 0.4, 90)
label("Clean up everything!", 0.52, 40)
label("Tip: " .. TIPS[math.random(1, #TIPS)], 0.85, 40, 22)

gui.Parent = playerGui

task.spawn(function()
	local t = 0
	while gui.Parent do
		t += 0.05
		title.Rotation = math.sin(t * 2) * 3
		task.wait(0.05)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- give the client a moment to build the HUD, then fade out
task.wait(1.5)
local info = TweenInfo.new(0.6)
TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
for _, d in background:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.65)
gui:Destroy()
