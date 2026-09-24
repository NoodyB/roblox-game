--!strict
-- PC/console shortcuts. Touch players use the on-screen buttons; nothing requires a keyboard.

local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent.UI
local HUD = require(UI.HUD)
local WindowManager = require(UI.WindowManager)

local Input = {}

function Input:Init()
	local bindings: { [Enum.KeyCode]: string } = {}
	for _, item in HUD.MenuItems do
		local keyCode = (Enum.KeyCode :: any)[item.hotkey]
		if keyCode then
			bindings[keyCode] = item.key
		end
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = bindings[input.KeyCode]
		if key then
			WindowManager.toggle(key)
		elseif input.KeyCode == Enum.KeyCode.ButtonB and WindowManager.isOpen() then
			WindowManager.close() -- gamepad back
		end
	end)
end

return Input
