--!strict
-- Critter collection: equip up to your slot count, merge 5 duplicates into a Golden critter, and
-- browse the Critter Book with every species' drop odds (critters are free drops, never sold).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local GameConfig = require(Shared.Config.GameConfig)
local Critters = require(Shared.Config.Critters)
local Zones = require(Shared.Config.Zones)
local CritterLogic = require(Shared.Logic.CritterLogic)
local EventLogic = require(Shared.Logic.EventLogic)
local Events = require(Shared.Config.Events)
local CritterModels = require(Shared.World.CritterModels)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors

local function bonusText(critter: Critters.Critter, golden: boolean): string
	local value = critter.value * (if golden then GameConfig.GoldenBonusMultiplier else 1)
	local label = Critters.BonusLabels[critter.bonus]
	if critter.bonus == "radius" or critter.bonus == "speed" then
		return string.format("+%s %s", tostring(math.floor(value * 10 + 0.5) / 10), label)
	end
	return string.format("+%d%% %s", math.floor(value * 100 + 0.5), label)
end

-- A small 3D preview of a critter.
local function viewport(parent: Instance, critterId: string, golden: boolean, silhouette: boolean?): ViewportFrame
	local vp = C.new("ViewportFrame", {
		Size = UDim2.new(1, -16, 0, 100),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(240, 232, 214),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1, 1),
		Parent = parent,
	}, { C.corner(10) })
	local model = CritterModels.build(critterId, golden, vp, CFrame.Angles(0, math.rad(25), 0), 1)
	if model and silhouette then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(40, 34, 40)
				d.Material = Enum.Material.SmoothPlastic
			elseif d:IsA("Light") then
				d:Destroy()
			end
		end
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.4, -7.5), Vector3.new(0, 1.5, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

return function(request: (string, any?) -> (boolean, any))
	type Card = { frame: Frame, count: TextLabel, equip: C.Button, golden: C.Button? }
	local owned: { [string]: Card } = {}
	local ownedGrid: ScrollingFrame
	local bookGrid: ScrollingFrame
	local header: TextLabel
	local empty: TextLabel
	local tabs: { [string]: C.Button } = {}
	local bookCards: { [string]: { frame: Frame, discovered: boolean } } = {}
	local latest: any = nil

	local function equippedCounts(state: any): { [string]: number }
		local counts = {}
		for _, entry in state.equipped do
			counts[entry] = (counts[entry] or 0) + 1
		end
		return counts
	end

	local function toggleEquip(entry: string)
		local state = latest
		if not state then
			return
		end
		local list = table.clone(state.equipped)
		local index = table.find(list, entry)
		if index then
			table.remove(list, index)
		else
			local slots = state.derived.equipSlots
			if #list >= slots then
				table.remove(list, 1) -- replace the oldest
			end
			table.insert(list, entry)
		end
		request("EquipCritters", list)
	end

	local function makeOwnedCard(entry: string, critter: Critters.Critter, golden: boolean): Card
		local rarity = Critters.Rarities[critter.rarity]
		local frame = C.card({
			Name = entry,
			BackgroundColor3 = if golden then Color3.fromRGB(255, 244, 200) else Colors.Card,
			StrokeColor = rarity.color,
			LayoutOrder = (if golden then 0 else 1000) + critter.zone * 10 + rarity.order,
			Parent = ownedGrid,
		})
		viewport(frame, critter.id, golden)
		C.label({ Text = (if golden then "✨ " else "") .. critter.name, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 110), Parent = frame })
		C.label({ Text = critter.rarity .. " · " .. bonusText(critter, golden), Font = Theme.Fonts.Bold, TextColor3 = Colors.TextLight, Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 134), Parent = frame })
		local count = C.outlined({ Text = "x1", Size = UDim2.fromOffset(50, 26), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), Parent = frame })
		local equip = C.button({
			Text = "Equip",
			Size = UDim2.new(if golden then 1 else 0.5, -12, 0, 40),
			Position = UDim2.new(0, 8, 1, -50),
			Color = Colors.Blue,
			DarkColor = Colors.BlueDark,
			Parent = frame,
			OnClick = function()
				toggleEquip(entry)
			end,
		})
		local goldenButton: C.Button? = nil
		if not golden then
			goldenButton = C.button({
				Text = "✨ Gold (5)",
				Size = UDim2.new(0.5, -12, 0, 40),
				Position = UDim2.new(0.5, 4, 1, -50),
				Color = Colors.Gold,
				DarkColor = Colors.GoldDark,
				Parent = frame,
				OnClick = function()
					request("MakeGolden", critter.id)
				end,
			})
		end
		return { frame = frame, count = count, equip = equip, golden = goldenButton }
	end

	local function refreshBook(state: any)
		for id, card in bookCards do
			local discovered = state.discovered[id] == true
			if discovered ~= card.discovered then
				card.discovered = discovered
				local vp = card.frame:FindFirstChildOfClass("ViewportFrame")
				if vp then
					vp:Destroy()
				end
				viewport(card.frame, id, false, not discovered)
				local nameLabel = card.frame:FindFirstChild("CritterName") :: TextLabel?
				if nameLabel then
					nameLabel.Text = if discovered then Critters.ById[id].name else "???"
				end
			end
		end
	end

	local function refresh(state: any)
		latest = state
		local slots = state.derived.equipSlots
		header.Text = string.format("🐾 Equipped %d / %d", math.min(#state.equipped, slots), slots)
		local counts = equippedCounts(state)
		local any = false
		for _, critter in Critters.List do
			local entry = state.critters[critter.id]
			for _, golden in { false, true } do
				local key = if golden then "golden:" .. critter.id else critter.id
				local amount = if entry then (if golden then entry.golden else entry.count) else 0
				local card = owned[key]
				if amount > 0 then
					any = true
					if not card then
						card = makeOwnedCard(key, critter, golden)
						owned[key] = card
					end
					card.frame.Visible = true
					card.count.Text = "x" .. amount
					local isEquipped = (counts[key] or 0) > 0
					card.equip.setText(if isEquipped then "Unequip" else "Equip")
					card.equip.setColor(if isEquipped then Colors.Grey else Colors.Blue, if isEquipped then Colors.GreyDark else Colors.BlueDark)
					if card.golden then
						card.golden.setEnabled(amount - (counts[key] or 0) >= GameConfig.GoldenCost)
					end
				elseif card then
					card.frame.Visible = false
				end
			end
		end
		empty.Visible = not any
		refreshBook(state)
	end

	local function selectTab(tab: string)
		ownedGrid.Visible = tab == "Mine"
		bookGrid.Visible = tab == "Book"
		for key, button in tabs do
			if key == tab then
				button.setColor(Colors.Green, Colors.GreenDark)
			else
				button.setColor(Colors.Grey, Colors.GreyDark)
			end
		end
	end

	local function build(content: Frame)
		local top = C.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = content })
		tabs.Mine = C.button({ Text = "My Critters", Size = UDim2.fromOffset(180, 46), Parent = top, OnClick = function()
			selectTab("Mine")
		end })
		tabs.Book = C.button({ Text = "📖 Critter Book", Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(192, 0), Parent = top, OnClick = function()
			selectTab("Book")
		end })
		header = C.label({ Size = UDim2.fromOffset(200, 40), Position = UDim2.new(1, -170, 0, 4), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
		C.button({
			Text = "Equip Best",
			Size = UDim2.fromOffset(160, 46),
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Color = Colors.Purple,
			DarkColor = Colors.PurpleDark,
			Parent = top,
			OnClick = function()
				request("AutoEquip")
			end,
		})

		ownedGrid = C.scroll({ Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 62), Parent = content })
		C.grid(UDim2.fromOffset(170, 210), 10).Parent = ownedGrid
		C.padding(6).Parent = ownedGrid
		empty = C.label({
			Text = "No critters yet! Keep cleaning — critters hide in the debris. 🍂",
			Font = Theme.Fonts.Bold,
			TextColor3 = Colors.TextLight,
			Size = UDim2.new(1, -40, 0, 60),
			Position = UDim2.new(0.5, 0, 0, 120),
			AnchorPoint = Vector2.new(0.5, 0),
			Visible = false,
			Parent = content,
		})

		bookGrid = C.scroll({ Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 62), Visible = false, Parent = content })
		C.grid(UDim2.fromOffset(170, 190), 10).Parent = bookGrid
		C.padding(6).Parent = bookGrid
		for zoneId = 1, #Zones do
			for _, odds in CritterLogic.odds(zoneId) do
				local critter = odds.critter
				local rarity = Critters.Rarities[critter.rarity]
				local frame = C.card({ Name = critter.id, StrokeColor = rarity.color, LayoutOrder = zoneId * 10 + rarity.order, Parent = bookGrid })
				viewport(frame, critter.id, false, true)
				C.label({ Name = "CritterName", Text = "???", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 110), Parent = frame })
				C.label({
					Text = string.format("%s %s · %s", Zones[zoneId].emoji, critter.rarity, bonusText(critter, false)),
					Font = Theme.Fonts.Bold,
					TextColor3 = Colors.TextLight,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 134),
					Parent = frame,
				})
				C.label({
					Text = string.format("Find chance: %d%%", math.floor(odds.chance * 100 + 0.5)),
					Font = Theme.Fonts.Bold,
					TextColor3 = rarity.color,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 158),
					Parent = frame,
				})
				bookCards[critter.id] = { frame = frame, discovered = false }
			end
		end
		-- seasonal critters (free event drops) with their overall odds during the event
		for index, event in Events do
			for _, odds in EventLogic.odds(event) do
				local critter = odds.critter
				local rarity = Critters.Rarities[critter.rarity]
				local frame = C.card({ Name = critter.id, StrokeColor = rarity.color, LayoutOrder = 1000 + index * 10 + rarity.order, Parent = bookGrid })
				viewport(frame, critter.id, false, true)
				C.label({ Name = "CritterName", Text = "???", Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 110), Parent = frame })
				C.label({
					Text = string.format("%s %s event · %s", event.emoji, event.name, bonusText(critter, false)),
					Font = Theme.Fonts.Bold,
					TextColor3 = Colors.TextLight,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 134),
					Parent = frame,
				})
				C.label({
					Text = string.format("%.0f%% of finds during event", odds.chance * 100),
					Font = Theme.Fonts.Bold,
					TextColor3 = rarity.color,
					Size = UDim2.new(1, -12, 0, 18),
					Position = UDim2.fromOffset(6, 158),
					Parent = frame,
				})
				bookCards[critter.id] = { frame = frame, discovered = false }
			end
		end
		selectTab("Mine")
	end

	return {
		key = "Critters",
		title = "🐿️ Critter Club",
		color = Colors.Green,
		darkColor = Colors.GreenDark,
		build = build,
		refresh = refresh,
	}
end
