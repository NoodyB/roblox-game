--!strict
-- Player settings (saved to the profile): music, sound effects, low graphics, others' critters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

return function(request: (string, any?) -> (boolean, any))
	local OPTIONS = {
		{ key = "music", label = "🎵 Music" },
		{ key = "sfx", label = "🔊 Sound Effects" },
		{ key = "lowGraphics", label = "🔋 Low Graphics (faster on older phones)" },
		{ key = "showCritters", label = "🐾 Show other players' critters" },
	}
	local toggles: { [string]: C.Button } = {}
	local values: { [string]: boolean } = {}
	local skipButton: C.Button
	local tempNote: TextLabel

	local function paint(key: string)
		local on = values[key] == true
		local button = toggles[key]
		button.setText(if on then "ON" else "OFF")
		button.setColor(if on then Colors.Green else Colors.Grey, if on then Colors.GreenDark else Colors.GreyDark)
	end

	local function refresh(state: any)
		for _, option in OPTIONS do
			values[option.key] = state.settings[option.key] == true
			paint(option.key)
		end
		skipButton.root.Visible = state.tutorialStep < 5
		tempNote.Visible = state.temporaryData == true
	end

	local function build(content: Frame)
		C.list(Enum.FillDirection.Vertical, 10).Parent = content
		for index, option in OPTIONS do
			local card = C.card({ Size = UDim2.new(1, 0, 0, 64), LayoutOrder = index, Parent = content })
			C.label({ Text = option.label, Size = UDim2.new(1, -170, 0, 32), Position = UDim2.fromOffset(16, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local key = option.key
			toggles[key] = C.button({
				Text = "ON",
				Size = UDim2.fromOffset(120, 46),
				Position = UDim2.new(1, -14, 0.5, -3),
				AnchorPoint = Vector2.new(1, 0.5),
				Parent = card,
				OnClick = function()
					values[key] = not values[key]
					paint(key)
					request("SaveSettings", { [key] = values[key] })
				end,
			})
		end
		skipButton = C.button({
			Text = "Skip tutorial",
			Size = UDim2.fromOffset(220, 48),
			Color = Colors.Grey,
			DarkColor = Colors.GreyDark,
			LayoutOrder = 20,
			Parent = content,
			OnClick = function()
				request("SkipTutorial")
			end,
		})
		tempNote = C.label({
			Text = "⚠️ Test mode: progress in this server is not being saved.",
			TextColor3 = Colors.RedDark,
			Font = Theme.Fonts.Bold,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 30,
			Visible = false,
			Parent = content,
		})
		C.label({
			Text = GameConfig.GameName .. " v" .. GameConfig.Version,
			Font = Theme.Fonts.Bold,
			TextColor3 = Colors.TextLight,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = 40,
			Parent = content,
		})
	end

	return {
		key = "Settings",
		title = "⚙️ Settings",
		color = Colors.Grey,
		darkColor = Colors.GreyDark,
		build = build,
		refresh = refresh,
	}
end
