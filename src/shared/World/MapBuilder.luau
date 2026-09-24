--!strict
-- Builds the whole world procedurally from ZoneLayout + Zones config: the hub town, eight themed
-- zones, walls, gates, sell stations, props and backdrop scenery. Runs on the server at startup
-- and offline in tests (where Lune validates every class/property against the Roblox API).
--
-- Performance notes: every part is anchored; decorative parts have CanCollide/CanQuery/CanTouch
-- off; small details don't cast shadows. Total part count stays around ~1.5k.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local Rng = require(Shared.Util.Rng)
local Format = require(Shared.Util.Format)
local Build = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local MapBuilder = {}

export type BoardRefs = { title: TextLabel, rows: { TextLabel } }
export type MapRefs = {
	map: Folder,
	gates: { [number]: BasePart },
	boards: { [string]: BoardRefs },
	spawn: BasePart,
	prompts: { ProximityPrompt },
}

local GROUND_TOP = 0.2
local WALL_THICKNESS = 2
local MEADOW = rgb(116, 164, 86)

local function groundCF(x: number, z: number): CFrame
	return CF(x, GROUND_TOP, z)
end

-- Invisible collision wall from (x1, z1) to (x2, z2) along one axis.
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	if length <= 0.01 then
		return
	end
	local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local size = if alongX
		then V(length, GameConfig.WallHeight, WALL_THICKNESS)
		else V(WALL_THICKNESS, GameConfig.WallHeight, length)
	local p = Build.block(parent, size, CF((x1 + x2) / 2, GameConfig.WallHeight / 2, (z1 + z2) / 2), rgb(255, 255, 255), {
		collide = true,
		transparency = 1,
		shadow = false,
		name = "Wall",
	})
	p.CanQuery = false
end

-- Visible low hedge/fence along a segment.
local function hedge(parent: Instance, x1: number, z1: number, x2: number, z2: number, color: Color3, material: Enum.Material)
	local length = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	if length <= 0.5 then
		return
	end
	local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local size = if alongX then V(length, 3.5, 3) else V(3, 3.5, length)
	Build.block(parent, size, CF((x1 + x2) / 2, GROUND_TOP + 1.75, (z1 + z2) / 2), color, {
		material = material,
		collide = true,
		name = "Hedge",
	})
end

-- Walls + hedges around a square area, leaving openings of GateWidth on west/east at z = 0.
local function enclose(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number, openWest: boolean, openEast: boolean, color: Color3, material: Enum.Material)
	local half = GameConfig.GateWidth / 2
	local folder = Build.folder("Boundary", parent)
	for _, spec in { { minZ, true }, { maxZ, true } } do
		local z = spec[1]
		wall(folder, minX, z, maxX, z)
		hedge(folder, minX, z, maxX, z, color, material)
	end
	for _, spec in { { minX, openWest }, { maxX, openEast } } do
		local x, open = spec[1], spec[2]
		if open then
			wall(folder, x, minZ, x, -half)
			wall(folder, x, half, x, maxZ)
			hedge(folder, x, minZ, x, -half, color, material)
			hedge(folder, x, half, x, maxZ, color, material)
		else
			wall(folder, x, minZ, x, maxZ)
			hedge(folder, x, minZ, x, maxZ, color, material)
		end
	end
end

local function corridor(parent: Instance, fromX: number, toX: number, pathColor: Color3)
	local folder = Build.folder("Corridor", parent)
	local length = toX - fromX
	local width = GameConfig.GateWidth
	Build.block(folder, V(length, 1, width), CF((fromX + toX) / 2, GROUND_TOP - 0.45, 0), pathColor, {
		material = Enum.Material.Cobblestone,
		collide = true,
		shadow = false,
		name = "Path",
	})
	for _, z in { -width / 2 - 1, width / 2 + 1 } do
		wall(folder, fromX, z, toX, z)
		-- wooden fence: rail + posts
		Build.block(folder, V(length, 0.5, 0.4), CF((fromX + toX) / 2, GROUND_TOP + 2.2, z), rgb(150, 105, 70), { material = Enum.Material.Wood })
		Build.block(folder, V(length, 0.5, 0.4), CF((fromX + toX) / 2, GROUND_TOP + 1.1, z), rgb(150, 105, 70), { material = Enum.Material.Wood })
		local posts = math.max(2, math.floor(length / 8))
		for i = 0, posts do
			local x = fromX + length * i / posts
			Build.block(folder, V(0.7, 3, 0.7), CF(x, GROUND_TOP + 1.5, z), rgb(120, 84, 56), { material = Enum.Material.Wood })
		end
	end
end

local function arch(parent: Instance, x: number, label: string, color: Color3)
	local folder = Build.folder("Arch", parent)
	local half = GameConfig.GateWidth / 2 + 1.5
	for _, z in { -half, half } do
		Build.block(folder, V(3, 19, 3), CF(x, GROUND_TOP + 9.5, z), Build.shade(color, 0.85), { collide = true, name = "Pillar" })
		Build.ball(folder, V(3.6, 3.6, 3.6), CF(x, GROUND_TOP + 19.5, z), color, { shadow = false })
	end
	local beam = Build.block(folder, V(3, 4, half * 2 + 3), CF(x, GROUND_TOP + 17, 0), color, { name = "Beam" })
	Build.surfaceText(beam, Enum.NormalId.Left, label, rgb(255, 255, 255), 30)
	Build.surfaceText(beam, Enum.NormalId.Right, label, rgb(255, 255, 255), 30)
	return folder
end

local function gate(parent: Instance, zoneId: number, prompts: { ProximityPrompt }): BasePart
	local zone = Zones[zoneId]
	local x = ZoneLayout.gatePosition(zoneId)
	local barrier = Build.block(parent, V(1, GameConfig.GateHeight, GameConfig.GateWidth), CF(x, GROUND_TOP + GameConfig.GateHeight / 2, 0), zone.theme.accent, {
		material = Enum.Material.ForceField,
		collide = true,
		shadow = false,
		name = "Gate",
	})
	barrier.CanQuery = true
	barrier:SetAttribute("ZoneId", zoneId)
	barrier:AddTag("ZoneGate")
	local text = string.format("🔒 %s\n%s 🪙", zone.name, Format.abbreviate(zone.unlockCost))
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local label = Build.surfaceText(barrier, face, text, rgb(255, 255, 255), 24)
		label.Name = "GateLabel"
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockPrompt"
	prompt.ActionText = "Unlock (" .. Format.abbreviate(zone.unlockCost) .. " coins)"
	prompt.ObjectText = zone.emoji .. " " .. zone.name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneId)
	prompt.Parent = barrier
	table.insert(prompts, prompt)
	return barrier
end

local function sellStation(parent: Instance, x: number, z: number)
	local folder = Build.folder("SellStation", parent)
	Build.cylinder(folder, 0.25, 17.5, CF(x, GROUND_TOP + 0.12, z), rgb(60, 200, 110), {
		material = Enum.Material.Neon,
		shadow = false,
		name = "PadGlow",
	})
	local pad = Build.cylinder(folder, 0.3, 16, CF(x, GROUND_TOP + 0.2, z), rgb(90, 210, 130), {
		material = Enum.Material.SmoothPlastic,
		shadow = false,
		name = "SellPad",
	})
	pad:AddTag("SellPad")
	local bb = Instance.new("BillboardGui")
	bb.Name = "SellSign"
	bb.Size = UDim2.new(10, 0, 3, 0)
	bb.StudsOffset = V(0, 7, 0)
	bb.MaxDistance = 150
	bb.LightInfluence = 0
	bb.Parent = pad
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "💰 SELL"
	label.TextColor3 = rgb(255, 255, 255)
	label.TextStrokeColor3 = rgb(30, 110, 60)
	label.TextStrokeTransparency = 0
	label.Parent = bb

	-- compost bin next to the pad
	local bx, bz = x, z - 9.5
	Build.block(folder, V(6, 5, 4), CF(bx, GROUND_TOP + 2.5, bz), rgb(60, 150, 80), { name = "Bin" })
	Build.block(folder, V(6.4, 0.8, 4.4), CF(bx, GROUND_TOP + 5.3, bz), rgb(40, 110, 60), { name = "Lid" })
	local front = Build.block(folder, V(4, 2.4, 0.2), CF(bx, GROUND_TOP + 2.6, bz + 2.05), rgb(250, 250, 240), { shadow = false, name = "Label" })
	Build.surfaceText(front, Enum.NormalId.Back, "♻️ COMPOST", rgb(40, 110, 60), 30)
	return pad
end

local function scatterBackdrop(parent: Instance, zoneId: number, cx: number, theme: any)
	local rng = Rng.new(55_000 + zoneId * 101)
	local folder = Build.folder("Backdrop", parent)
	local treeKind = Props.BackdropTrees[theme.props] or "autumnTree"
	for i = 1, 12 do
		local side = if i % 2 == 0 then 1 else -1
		local x = cx + rng:range(-95, 95)
		local z = side * rng:range(88, 170)
		Props.build(treeKind, folder, CF(x, 0, z) * CFrame.Angles(0, rad(rng:range(0, 360)), 0), rng:range(1.1, 1.7), theme)
	end
	local landmark = Props.Landmarks[theme.props] or "house"
	Props.build(landmark, folder, CF(cx - 35, 0, -112) * CFrame.Angles(0, rad(rng:range(-20, 20)), 0), 1.2, theme)
	Props.build(landmark, folder, CF(cx + 40, 0, 118) * CFrame.Angles(0, rad(180 + rng:range(-20, 20)), 0), 1.1, theme)
end

local function buildZone(parent: Instance, zoneId: number, refs: MapRefs)
	local zone = Zones[zoneId]
	local theme = zone.theme
	local cx = ZoneLayout.center(zoneId)
	local minX, maxX, minZ, maxZ = ZoneLayout.bounds(zoneId)
	local folder = Build.folder(string.format("Zone%d_%s", zoneId, zone.key), parent)
	folder:SetAttribute("ZoneId", zoneId)

	-- themed biome ground around the zone (between the meadow and the zone floor), so every world
	-- reads as its own place from a distance
	Build.block(folder, V(GameConfig.ZoneSpacing, 1, 640), CF(cx, GROUND_TOP - 0.6, 0), Build.shade(theme.border, 0.95), {
		material = theme.borderMaterial,
		collide = true,
		shadow = false,
		name = "Biome",
	})
	Build.block(folder, V(GameConfig.ZoneSize, 1, GameConfig.ZoneSize), CF(cx, GROUND_TOP - 0.5, 0), theme.ground, {
		material = theme.groundMaterial,
		collide = true,
		shadow = false,
		name = "Ground",
	})
	-- walking path through the middle
	Build.block(folder, V(GameConfig.ZoneSize, 1, 12), CF(cx, GROUND_TOP - 0.48, 0), theme.path, {
		material = Enum.Material.SmoothPlastic,
		collide = true,
		shadow = false,
		name = "Path",
	})

	enclose(folder, minX, maxX, minZ, maxZ, true, zoneId < #Zones, theme.border, theme.borderMaterial)

	arch(folder, minX, zone.emoji .. " " .. zone.name, theme.accent)
	if zoneId > 1 then
		refs.gates[zoneId] = gate(folder, zoneId, refs.prompts)
	end

	for _, pad in ZoneLayout.sellPads(zoneId) do
		sellStation(folder, pad.x, pad.z)
	end

	local propsFolder = Build.folder("Props", folder)
	for _, prop in ZoneLayout.props(zoneId) do
		Props.build(prop.kind, propsFolder, groundCF(prop.x, prop.z) * CFrame.Angles(0, rad(prop.rotation), 0), prop.scale, theme)
	end

	scatterBackdrop(folder, zoneId, cx, theme)
end

local function shopBuilding(parent: Instance, position: Vector3, title: string, color: Color3, windowKey: string, prompts: { ProximityPrompt })
	local base = CFrame.lookAt(position, V(0, position.Y, 0))
	local m = Build.model(windowKey .. "Building", parent)
	Build.block(m, V(16, 9, 11), base * CF(0, 4.5, 2), rgb(252, 244, 228), { collide = true, name = "Walls" })
	Build.block(m, V(16.4, 1, 11.4), base * CF(0, 0.5, 2), Build.shade(color, 0.7), { collide = true, name = "Foundation" })
	Build.wedge(m, V(17, 4, 6), base * CF(0, 11, -1) , color, { name = "RoofFront" })
	Build.wedge(m, V(17, 4, 6), base * CF(0, 11, 5) * CFrame.Angles(0, rad(180), 0), color, { name = "RoofBack" })
	-- striped awning over the counter
	for i = 0, 5 do
		Build.wedge(m, V(2.6, 1.6, 3), base * CF(-6.5 + i * 2.6, 7.2, -4.8), if i % 2 == 0 then color else rgb(255, 255, 255), { shadow = true, name = "Awning" })
	end
	Build.block(m, V(12, 3, 2), base * CF(0, 1.5, -4.4), rgb(200, 150, 100), { material = Enum.Material.Wood, collide = true, name = "Counter" })
	local sign = Build.block(m, V(13, 3.4, 0.6), base * CF(0, 10.2, -3.9), rgb(255, 255, 255), { name = "Sign" })
	Build.surfaceText(sign, Enum.NormalId.Front, title, Build.shade(color, 0.6), 30)

	local anchor = Build.block(m, V(10, 6, 2), base * CF(0, 3, -7), rgb(255, 255, 255), { transparency = 1, shadow = false, name = "PromptAnchor" })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenWindow", windowKey)
	prompt.Parent = anchor
	table.insert(prompts, prompt)
	return m
end

local function leaderboard(parent: Instance, position: Vector3, key: string): BoardRefs
	local base = CFrame.lookAt(position, V(0, position.Y, 0))
	local folder = Build.folder("Leaderboard_" .. key, parent)
	for _, x in { -7.5, 7.5 } do
		Build.block(folder, V(1, 14, 1), base * CF(x, 7, 0.6), rgb(120, 84, 56), { material = Enum.Material.Wood, collide = true })
	end
	local board = Build.block(folder, V(16, 12, 0.6), base * CF(0, 9, 0), rgb(60, 44, 36), { material = Enum.Material.Wood, name = "Board" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.16)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = rgb(255, 214, 90)
	title.Text = "Leaderboard"
	title.Parent = gui
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0.05, 0.17 + (i - 1) * 0.082)
		row.Size = UDim2.fromScale(0.9, 0.078)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i <= 3 then rgb(255, 230, 150) else rgb(245, 235, 220)
		row.Text = ""
		row.Parent = gui
		table.insert(rows, row)
	end
	return { title = title, rows = rows }
end

local function buildHub(parent: Instance, refs: MapRefs)
	local folder = Build.folder("Hub", parent)
	local half = GameConfig.HubSize / 2
	Build.block(folder, V(GameConfig.HubSize, 1, GameConfig.HubSize), CF(0, GROUND_TOP - 0.5, 0), rgb(222, 208, 184), {
		material = Enum.Material.Pavement,
		collide = true,
		shadow = false,
		name = "Ground",
	})
	-- grass lawns in the corners
	for _, p in { V(-48, 0, -48), V(48, 0, -48), V(-48, 0, 48), V(48, 0, 48) } do
		Build.block(folder, V(44, 1, 44), CF(p.X, GROUND_TOP - 0.48, p.Z), rgb(126, 180, 90), {
			material = Enum.Material.Grass,
			collide = true,
			shadow = false,
			name = "Lawn",
		})
	end
	enclose(folder, -half, half, -half, half, false, true, rgb(92, 140, 62), Enum.Material.Grass)

	-- fountain
	local fountain = Build.folder("Fountain", folder)
	Build.cylinder(fountain, 2, 20, CF(0, GROUND_TOP + 1, 0), rgb(200, 196, 190), { material = Enum.Material.Marble, collide = true })
	Build.cylinder(fountain, 0.3, 18, CF(0, GROUND_TOP + 1.9, 0), rgb(90, 190, 240), { material = Enum.Material.Glass, transparency = 0.25, shadow = false })
	Build.cylinder(fountain, 6, 2.4, CF(0, GROUND_TOP + 4, 0), rgb(200, 196, 190), { material = Enum.Material.Marble })
	Build.cylinder(fountain, 1, 8, CF(0, GROUND_TOP + 7, 0), rgb(200, 196, 190), { material = Enum.Material.Marble })
	local top = Build.ball(fountain, V(3, 3, 3), CF(0, GROUND_TOP + 8.6, 0), rgb(255, 150, 60), { material = Enum.Material.SmoothPlastic })
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 25
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Speed = NumberRange.new(8, 11)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = V(0, -25, 0)
	spray.Size = NumberSequence.new(0.4, 0.1)
	spray.Color = ColorSequence.new(rgb(200, 235, 255))
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Parent = top

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V(12, 0.4, 12)
	spawn.CFrame = CFrame.lookAt(V(-30, GROUND_TOP + 0.2, 0), V(0, GROUND_TOP + 0.2, 0))
	spawn.Color = rgb(255, 196, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CanTouch = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	refs.spawn = spawn

	-- shops
	local shops = Build.folder("Shops", folder)
	shopBuilding(shops, V(-42, GROUND_TOP, -40), "🛒 Vacuum Shop", rgb(255, 138, 61), "Shop", refs.prompts)
	shopBuilding(shops, V(42, GROUND_TOP, -40), "🐿️ Critter Club", rgb(76, 194, 107), "Critters", refs.prompts)
	shopBuilding(shops, V(-42, GROUND_TOP, 40), "♻️ Rebirth Shrine", rgb(139, 92, 246), "Rebirth", refs.prompts)
	shopBuilding(shops, V(42, GROUND_TOP, 40), "📜 Quest Board", rgb(70, 160, 255), "Quests", refs.prompts)
	shopBuilding(shops, V(-62, GROUND_TOP, 0), "💎 Supply Store", rgb(255, 200, 61), "Store", refs.prompts)

	refs.boards.Units = leaderboard(folder, V(-12, GROUND_TOP, -66), "Units")
	refs.boards.Rebirths = leaderboard(folder, V(12, GROUND_TOP, -66), "Rebirths")

	-- decoration
	local deco = Build.folder("Decor", folder)
	for _, p in { V(-20, 0, -20), V(20, 0, -20), V(-20, 0, 20), V(20, 0, 20), V(60, 0, -12), V(60, 0, 12) } do
		Props.build("lamp", deco, groundCF(p.X, p.Z), 1)
	end
	for _, p in { V(-64, 0, -64), V(64, 0, -64), V(-64, 0, 64), V(64, 0, 64), V(-30, 0, -62), V(30, 0, 62), V(-30, 0, 62) } do
		Props.build("autumnTree", deco, groundCF(p.X, p.Z) * CFrame.Angles(0, rad(p.X * 7), 0), 1.2)
	end
	for _, p in { V(0, 0, 16), V(0, 0, -16) } do
		Props.build("bench", deco, groundCF(p.X, p.Z) * CFrame.Angles(0, rad(if p.Z > 0 then 0 else 180), 0), 1)
	end
	local backdrop = Build.folder("Backdrop", folder)
	for _, p in { V(-40, 0, -115), V(35, 0, -120), V(-35, 0, 118), V(40, 0, 112), V(-110, 0, -40), V(-115, 0, 45) } do
		Props.build("house", backdrop, CFrame.lookAt(p, V(0, 0, 0)), 1.1)
	end
	arch(folder, half, "🍂 To the Yards! →", rgb(255, 138, 61))
end

-- options.hubDecor: prop kind to scatter around the hub for a seasonal event (e.g. "jackOLantern")
function MapBuilder.build(parent: Instance, options: { hubDecor: string? }?): MapRefs
	local map = Build.folder("Map", nil)
	local refs: MapRefs = {
		map = map,
		gates = {},
		boards = {},
		spawn = nil :: any,
		prompts = {},
	}

	-- meadow under everything (split: parts are limited to 2048 studs per axis)
	local lastX = #Zones * GameConfig.ZoneSpacing + GameConfig.ZoneSize / 2 + 250
	local firstX = -GameConfig.HubSize / 2 - 250
	local mid = (firstX + lastX) / 2
	for _, span in { { firstX, mid }, { mid, lastX } } do
		Build.block(map, V(span[2] - span[1], 2, 700), CF((span[1] + span[2]) / 2, -1, 0), MEADOW, {
			material = Enum.Material.Grass,
			collide = true,
			shadow = false,
			name = "Meadow",
		})
	end

	buildHub(map, refs)
	if options and options.hubDecor then
		local seasonal = Build.folder("Seasonal", map)
		for i = 0, 11 do
			local angle = math.rad(i * 30 + 15)
			Props.build(options.hubDecor, seasonal, groundCF(math.cos(angle) * 30, math.sin(angle) * 30) * CFrame.Angles(0, -angle - math.rad(90), 0), 0.8)
		end
	end
	local zonesFolder = Build.folder("Zones", map)
	for zoneId = 1, #Zones do
		buildZone(zonesFolder, zoneId, refs)
		-- corridor from the previous area to this zone's gate
		local prevEdge = if zoneId == 1 then GameConfig.HubSize / 2 else ZoneLayout.center(zoneId - 1) + GameConfig.ZoneSize / 2
		local gateX = ZoneLayout.gatePosition(zoneId)
		corridor(zonesFolder, prevEdge, gateX, Zones[zoneId].theme.path)
	end

	map.Parent = parent
	return refs
end

MapBuilder.GroundTop = GROUND_TOP

return MapBuilder
