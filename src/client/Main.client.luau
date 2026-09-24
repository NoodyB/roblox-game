--!strict
-- Client entry point: builds the UI, wires controllers, then performs the server handshake.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")
local Windows = UI:WaitForChild("Windows")

local ClientState = require(Controllers.ClientState)
local Audio = require(Controllers.Audio)
local DebrisRenderer = require(Controllers.DebrisRenderer)
local Effects = require(Controllers.Effects)
local WorldView = require(Controllers.WorldView)
local CritterFollowers = require(Controllers.CritterFollowers)
local Tutorial = require(Controllers.Tutorial)
local Input = require(Controllers.Input)
local ChatTags = require(Controllers.ChatTags)

local Responsive = require(UI.Responsive)
local HUD = require(UI.HUD)
local Notifications = require(UI.Notifications)
local WindowManager = require(UI.WindowManager)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- No tools or health in this game; keep the screen clean.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- Controllers (Init connects listeners; no yielding except remote lookup)
Audio:Init()
ClientState:Init()
DebrisRenderer:Init()
Effects:Init()
WorldView:Init()
CritterFollowers:Init()
Tutorial:Init()
Input:Init()
pcall(function()
	ChatTags:Init()
end)

-- UI layers
Responsive.start()
local hudGui = Responsive.screen("SweepHUD", 1, playerGui)
local windowGui = Responsive.screen("SweepWindows", 5, playerGui)
local fxGui = Responsive.screen("SweepFX", 10, playerGui)

HUD.mount(hudGui)
HUD.setDebrisQueries(DebrisRenderer.cleanFraction, DebrisRenderer.isGolden)
Tutorial.mount(hudGui)
WindowManager.mount(windowGui)
Notifications.mount(fxGui)
Effects.mount(fxGui)
WorldView.mount(fxGui)

local request = ClientState.request
WindowManager.register(require(Windows.ShopWindow)(request))
WindowManager.register(require(Windows.CrittersWindow)(request))
WindowManager.register(require(Windows.QuestsWindow)(request))
WindowManager.register(require(Windows.RebirthWindow)(request))
WindowManager.register(require(Windows.TeleportWindow)(request, function()
	WindowManager.close()
end))
WindowManager.register(require(Windows.StoreWindow)())
WindowManager.register(require(Windows.SettingsWindow)(request))

ClientState.Changed:Connect(function(state)
	HUD.refresh(state)
	WindowManager.refresh(state)
	Audio.applySettings(state.settings)
end)

-- World buildings open their windows through proximity prompts.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local key = prompt:GetAttribute("OpenWindow")
	if type(key) == "string" then
		WindowManager.open(key)
	end
end)

-- Start loops + handshake
DebrisRenderer:Start()
WorldView:Start()
CritterFollowers:Start()
Tutorial:Start()
ClientState:Start()

task.spawn(function()
	while true do
		HUD.tick()
		task.wait(0.1)
	end
end)
