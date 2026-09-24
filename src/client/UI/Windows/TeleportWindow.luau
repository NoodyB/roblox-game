--!strict
-- Travel between the hub and unlocked zones (free, 3s cooldown enforced by the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

return function(request: (string, any?) -> (boolean, any), onTraveled: () -> ())
	type Row = { button: C.Button, status: TextLabel }
	local rows: { [number]: Row } = {}

	local function refresh(state: any)
		for zoneId, row in rows do
			local unlocked = zoneId == 0 or zoneId <= state.maxZone
			row.button.root.Visible = unlocked
			row.status.Visible = not unlocked
			if not unlocked then
				local zone = Zones[zoneId]
				row.status.Text = if zoneId == state.maxZone + 1
					then "🔒 Unlock at its gate: " .. Format.abbreviate(zone.unlockCost) .. " 🪙"
					else "🔒 Locked"
			end
		end
	end

	local function build(content: Frame)
		local list = C.scroll({ Parent = content })
		C.list(Enum.FillDirection.Vertical, 8).Parent = list
		C.padding(6, 8).Parent = list
		local entries = { { id = 0, emoji = "🏡", name = "Maple Hollow (Hub)", color = Colors.Accent } }
		for _, zone in Zones do
			table.insert(entries, { id = zone.id, emoji = zone.emoji, name = zone.name, color = zone.theme.accent })
		end
		for index, entry in entries do
			local card = C.card({ Size = UDim2.new(1, -16, 0, 66), LayoutOrder = index, Parent = list })
			local swatch = C.card({ Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = entry.color, CornerRadius = 12, Parent = card })
			C.outlined({ Text = entry.emoji, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = swatch })
			C.label({ Text = entry.name, Size = UDim2.new(0.55, 0, 0, 34), Position = UDim2.fromOffset(70, 16), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local id = entry.id
			local button = C.button({
				Text = "Go!",
				Size = UDim2.fromOffset(140, 48),
				Position = UDim2.new(1, -12, 0.5, -3),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = Colors.Blue,
				DarkColor = Colors.BlueDark,
				Parent = card,
				OnClick = function()
					local ok = request("Teleport", id)
					if ok then
						onTraveled()
					end
				end,
			})
			local status = C.label({
				Font = Theme.Fonts.Bold,
				TextColor3 = Colors.TextLight,
				Size = UDim2.fromOffset(300, 30),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = card,
			})
			rows[id] = { button = button, status = status }
		end
	end

	return {
		key = "Teleport",
		title = "🗺️ Travel",
		color = Color3.fromRGB(80, 190, 200),
		darkColor = Color3.fromRGB(50, 140, 150),
		build = build,
		refresh = refresh,
	}
end
