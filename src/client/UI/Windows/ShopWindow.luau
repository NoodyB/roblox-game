--!strict
-- Coin shop: three upgrade tracks (vacuums, bags, boots). Only the next tier can be bought, so the
-- choice is always obvious; the full ladder is visible so players can see what's ahead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Upgrades = require(Shared.Config.Upgrades)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

type Row = { card: Frame, status: TextLabel, buy: C.Button }

return function(request: (string, any?) -> (boolean, any))
	local TRACKS = {
		{ key = "Vacuums", emoji = "🧹", field = "vacuumTier" },
		{ key = "Bags", emoji = "🎒", field = "bagTier" },
		{ key = "Boots", emoji = "👟", field = "bootsTier" },
	}
	local current = "Vacuums"
	local lists: { [string]: ScrollingFrame } = {}
	local rows: { [string]: { Row } } = {}
	local tabs: { [string]: C.Button } = {}
	local lastState: any = nil

	local function statText(track: string, tier: any): string
		if track == "Vacuums" then
			return string.format("Reach %s · Power %d", tostring(tier.radius), tier.power)
		elseif track == "Bags" then
			return "Holds " .. Format.abbreviate(tier.capacity)
		end
		return "Walk speed " .. tier.speed
	end

	local function refresh(state: any)
		lastState = state
		for _, track in TRACKS do
			local owned = state[track.field]
			for index, row in rows[track.key] do
				local tier = (Upgrades :: any)[track.key][index]
				if index <= owned then
					row.status.Text = if index == owned then "✅ Equipped" else "✓ Owned"
					row.status.Visible = true
					row.buy.root.Visible = false
					row.card.BackgroundColor3 = if index == owned then Color3.fromRGB(226, 248, 226) else Colors.Card
				elseif index == owned + 1 then
					row.status.Visible = false
					row.buy.root.Visible = true
					row.buy.setText("🪙 " .. Format.abbreviate(tier.cost))
					local affordable = state.coins >= tier.cost
					row.buy.setEnabled(affordable)
					row.card.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
				else
					row.status.Text = "🔒 " .. Format.abbreviate(tier.cost)
					row.status.Visible = true
					row.buy.root.Visible = false
					row.card.BackgroundColor3 = Colors.BackgroundDark
				end
			end
		end
	end

	local function select(track: string)
		current = track
		for key, list in lists do
			list.Visible = key == track
		end
		for key, tab in tabs do
			if key == track then
				tab.setColor(Colors.Accent, Colors.AccentDark)
			else
				tab.setColor(Colors.Grey, Colors.GreyDark)
			end
		end
	end

	local function build(content: Frame)
		local tabRow = C.new("Frame", {
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			Parent = content,
		}, { C.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })
		for i, track in TRACKS do
			tabs[track.key] = C.button({
				Text = track.emoji .. " " .. track.key,
				Size = UDim2.fromOffset(200, 48),
				LayoutOrder = i,
				Parent = tabRow,
				OnClick = function()
					select(track.key)
				end,
			})
			local list = C.scroll({
				Name = track.key,
				Size = UDim2.new(1, 0, 1, -66),
				Position = UDim2.fromOffset(0, 66),
				Visible = false,
				Parent = content,
			})
			C.list(Enum.FillDirection.Vertical, 8).Parent = list
			C.padding(6, 8).Parent = list
			lists[track.key] = list
			rows[track.key] = {}
			for index, tier in (Upgrades :: any)[track.key] do
				local card = C.card({
					Size = UDim2.new(1, -16, 0, 74),
					LayoutOrder = index,
					Parent = list,
				})
				local swatch = C.card({
					Size = UDim2.fromOffset(54, 54),
					Position = UDim2.fromOffset(10, 10),
					BackgroundColor3 = tier.color,
					CornerRadius = 12,
					Parent = card,
				})
				C.outlined({ Text = track.emoji, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = swatch })
				C.label({
					Text = string.format("%d. %s", index, tier.name),
					Size = UDim2.new(0.55, 0, 0, 30),
					Position = UDim2.fromOffset(76, 8),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
				C.label({
					Text = statText(track.key, tier),
					Font = Theme.Fonts.Bold,
					TextColor3 = Colors.TextLight,
					Size = UDim2.new(0.55, 0, 0, 24),
					Position = UDim2.fromOffset(76, 40),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
				local status = C.label({
					Text = "",
					Size = UDim2.fromOffset(190, 34),
					Position = UDim2.new(1, -16, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = card,
				})
				local trackKey = track.key
				local buy = C.button({
					Text = "Buy",
					Size = UDim2.fromOffset(170, 50),
					Position = UDim2.new(1, -14, 0.5, -3),
					AnchorPoint = Vector2.new(1, 0.5),
					Parent = card,
					OnClick = function()
						request("BuyUpgrade", trackKey)
					end,
				})
				table.insert(rows[track.key], { card = card, status = status, buy = buy })
			end
		end
		select(current)
		if lastState then
			refresh(lastState)
		end
	end

	return {
		key = "Shop",
		title = "🛒 Vacuum Shop",
		color = Colors.Accent,
		darkColor = Colors.AccentDark,
		build = build,
		refresh = refresh,
	}
end
