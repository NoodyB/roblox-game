--!strict
-- Rebirth: reset coins/upgrades/zones for a permanent +50% coin multiplier and Rebirth Tokens,
-- spent on permanent perks. Requires a double tap to confirm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Progression = require(Shared.Config.Progression)
local Economy = require(Shared.Logic.Economy)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

return function(request: (string, any?) -> (boolean, any))
	local info: TextLabel
	local bar: C.ProgressBar
	local rebirthButton: C.Button
	local tokens: TextLabel
	type PerkRow = { level: TextLabel, buy: C.Button }
	local perkRows: { [string]: PerkRow } = {}
	local confirmUntil = 0
	local latest: any = nil

	local function refresh(state: any)
		latest = state
		local cost = Economy.rebirthCost(state.rebirths)
		local now = Stats.rebirthMultiplier(state.rebirths)
		local nextMult = Stats.rebirthMultiplier(state.rebirths + 1)
		info.Text = string.format("Rebirths: %d   ·   Coin bonus x%s → x%s", state.rebirths, tostring(now), tostring(nextMult))
		bar.set(state.coins / cost, string.format("🪙 %s / %s", Format.abbreviate(state.coins), Format.abbreviate(cost)))
		local ready = state.coins >= cost
		rebirthButton.setEnabled(ready)
		if os.clock() > confirmUntil then
			rebirthButton.setText(if ready then "♻️ REBIRTH!" else "Need " .. Format.abbreviate(cost - state.coins) .. " more")
		end
		tokens.Text = string.format("🔷 %d Rebirth Token%s", state.rebirthTokens, if state.rebirthTokens == 1 then "" else "s")
		for _, perk in Progression.Perks do
			local row = perkRows[perk.id]
			local level = state.perks[perk.id] or 0
			row.level.Text = string.format("Lv %d/%d", level, perk.maxLevel)
			local maxed = level >= perk.maxLevel
			row.buy.setText(if maxed then "MAX" else "🔷 " .. perk.costPerLevel)
			row.buy.setEnabled(not maxed and state.rebirthTokens >= perk.costPerLevel)
		end
	end

	local function build(content: Frame)
		local left = C.card({ Size = UDim2.new(0.5, -8, 1, 0), BackgroundColor3 = Color3.fromRGB(240, 232, 255), Parent = content })
		C.padding(14).Parent = left
		C.list(Enum.FillDirection.Vertical, 10).Parent = left
		C.label({ Text = "♻️ Start fresh, get stronger!", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = left })
		info = C.label({ Font = Theme.Fonts.Bold, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 2, Parent = left })
		bar = C.progress({ Size = UDim2.new(1, 0, 0, 34), Color = Colors.Purple, LayoutOrder = 3, Parent = left })
		C.label({
			Text = "Resets: coins, vacuums, bags, boots, zones.\nKeeps: critters, perks, tokens, passes, stats.\nReward: permanent +50% coins and a Rebirth Token.",
			Font = Theme.Fonts.Body,
			TextColor3 = Colors.TextLight,
			TextScaled = false,
			TextSize = 17,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 96),
			LayoutOrder = 4,
			Parent = left,
		})
		rebirthButton = C.button({
			Text = "♻️ REBIRTH!",
			Size = UDim2.new(1, 0, 0, 70),
			Color = Colors.Purple,
			DarkColor = Colors.PurpleDark,
			LayoutOrder = 5,
			Parent = left,
			OnClick = function()
				if os.clock() > confirmUntil then
					confirmUntil = os.clock() + 3
					rebirthButton.setText("Tap again to confirm!")
					return
				end
				confirmUntil = 0
				request("Rebirth")
				if latest then
					refresh(latest)
				end
			end,
		})

		local right = C.new("Frame", { Size = UDim2.new(0.5, -8, 1, 0), Position = UDim2.new(0.5, 8, 0, 0), BackgroundTransparency = 1, Parent = content })
		tokens = C.label({ Size = UDim2.new(1, 0, 0, 36), Parent = right })
		local list = C.scroll({ Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), Parent = right })
		C.list(Enum.FillDirection.Vertical, 8).Parent = list
		C.padding(4, 6).Parent = list
		for index, perk in Progression.Perks do
			local card = C.card({ Size = UDim2.new(1, -12, 0, 84), LayoutOrder = index, Parent = list })
			C.label({ Text = perk.emoji .. " " .. perk.name, Size = UDim2.new(0.62, 0, 0, 28), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			C.label({ Text = perk.description, Font = Theme.Fonts.Bold, TextColor3 = Colors.TextLight, Size = UDim2.new(0.62, 0, 0, 20), Position = UDim2.fromOffset(12, 38), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local level = C.label({ Font = Theme.Fonts.Bold, Size = UDim2.new(0.62, 0, 0, 18), Position = UDim2.fromOffset(12, 60), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local id = perk.id
			local buy = C.button({
				Text = "🔷 1",
				Size = UDim2.fromOffset(110, 50),
				Position = UDim2.new(1, -10, 0.5, -3),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = Colors.Purple,
				DarkColor = Colors.PurpleDark,
				Parent = card,
				OnClick = function()
					request("BuyPerk", id)
				end,
			})
			perkRows[perk.id] = { level = level, buy = buy }
		end
	end

	return {
		key = "Rebirth",
		title = "♻️ Rebirth Shrine",
		color = Colors.Purple,
		darkColor = Colors.PurpleDark,
		build = build,
		refresh = refresh,
	}
end
