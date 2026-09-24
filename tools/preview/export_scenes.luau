--!nocheck
-- Builds preview scenes from the REAL game modules (MapBuilder, DebrisRenderer, GearModels,
-- CritterModels) and exports their parts as JSON for the three.js viewer.
--   lune run tools/preview/export_scenes.luau
-- Output: tools/preview/scenes/<name>.json

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = require("../../tests/harness")
local ClientEnv = require("../../tests/clientenv")

Harness.reset()
local env = ClientEnv.install(Harness)

local R = function(path)
	return Harness.requirePath(path)
end
local Shared = "ReplicatedStorage.Shared."
local Client = "StarterPlayer.StarterPlayerScripts.Client."

local GameConfig = R(Shared .. "Config.GameConfig")
local Zones = R(Shared .. "Config.Zones")
local Critters = R(Shared .. "Config.Critters")
local ZoneLayout = R(Shared .. "Logic.ZoneLayout")
local DebrisGrid = R(Shared .. "Logic.DebrisGrid")
local NetCodec = R(Shared .. "Logic.NetCodec")
local DataSchema = R(Shared .. "Logic.DataSchema")
local Stats = R(Shared .. "Logic.Stats")
local MapBuilder = R(Shared .. "World.MapBuilder")
local GearModels = R(Shared .. "World.GearModels")
local CritterModels = R(Shared .. "World.CritterModels")
local Build = R(Shared .. "World.Build")
local ClientState = R(Client .. "Controllers.ClientState")
local DebrisRenderer = R(Client .. "Controllers.DebrisRenderer")

local V = roblox.Vector3.new
local CF = roblox.CFrame.new
local rgb = roblox.Color3.fromRGB

---------------------------------------------------------------------------------------------------
-- Build the world exactly as the game does
---------------------------------------------------------------------------------------------------

local worldRoot = ClientEnv.Instance.new("Folder")
MapBuilder.build(worldRoot, { hubDecor = "jackOLantern" })

ClientState:Init()
DebrisRenderer:Init()
local profile = DataSchema.new(0)
local state = DataSchema.clientView(profile)
state.derived = Stats.compute(profile)
state.passes = {}
state.storm = { endsAt = 0, by = "" }
local snapshot = {}
for zoneId = 1, #Zones do
	local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
	local grid = DebrisGrid.new({ cols = cols, rows = rows, cellSize = GameConfig.CellSize, originX = originX, originZ = originZ, cellMax = GameConfig.CellMax, mask = ZoneLayout.mask(zoneId) })
	grid:fill()
	snapshot[tostring(zoneId)] = { wave = 1, golden = zoneId == 4, cells = grid:snapshot() }
end
env.requestHandler = function(action)
	if action == "Hello" then
		return { ok = true, data = { state = state, debris = snapshot } }
	end
	return { ok = true }
end
ClientState:Start()
task.wait(0.05)
for zoneId = 1, #Zones do
	DebrisRenderer._buildZone(zoneId)
end
task.wait(0.3)

-- carve a "cleaned trail" through zone 1 (as if the squad has been vacuuming)
local function carve(zoneId: number, fromX: number, fromZ: number, toX: number, toZ: number, width: number)
	local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
	local dirty = { [zoneId] = {} }
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x = originX + (col + 0.5) * GameConfig.CellSize
			local z = originZ + (row + 0.5) * GameConfig.CellSize
			-- distance from point to segment
			local dx, dz = toX - fromX, toZ - fromZ
			local t = math.clamp(((x - fromX) * dx + (z - fromZ) * dz) / (dx * dx + dz * dz), 0, 1)
			local px, pz = fromX + t * dx, fromZ + t * dz
			if (x - px) ^ 2 + (z - pz) ^ 2 < width * width then
				dirty[zoneId][row * cols + col] = true
			end
		end
	end
	local delta = NetCodec.encodeDirty(dirty, function()
		return 0
	end)
	env.remotes.DebrisDelta.OnClientEvent:Fire(delta)
end
local z1 = ZoneLayout.center(1)
carve(1, z1 - 60, 40, z1 + 10, 10, 9)
carve(1, z1 + 10, 10, z1 + 40, 45, 7)

---------------------------------------------------------------------------------------------------
-- A blocky character with gear and critters (preview stand-in for a Roblox avatar)
---------------------------------------------------------------------------------------------------

local function character(parent, base: roblox.CFrame, shirt, vacuumTier: number, bagTier: number, critters: { string })
	local m = Build.model("Character", parent)
	local skin = rgb(255, 204, 153)
	local pants = rgb(60, 70, 110)
	Build.block(m, V(2, 2, 1), base * CF(0, 4, 0), shirt, { name = "UpperTorso" })
	Build.block(m, V(2, 0.6, 1), base * CF(0, 2.7, 0), pants, { name = "LowerTorso" })
	Build.block(m, V(0.9, 2.2, 0.9), base * CF(-0.5, 1.2, 0), pants, { name = "LeftLeg" })
	Build.block(m, V(0.9, 2.2, 0.9), base * CF(0.5, 1.2, 0), pants, { name = "RightLeg" })
	Build.block(m, V(0.9, 2, 0.9), base * CF(-1.5, 4, 0), skin, { name = "LeftArm" })
	-- right arm reaching forward holding the vacuum
	Build.block(m, V(0.9, 2, 0.9), base * CF(1.5, 4.2, -0.6) * roblox.CFrame.Angles(math.rad(60), 0, 0), shirt, { name = "RightArm" })
	Build.block(m, V(0.9, 0.9, 0.9), base * CF(1.5, 3.7, -1.6), skin, { name = "RightHand" })
	Build.ball(m, V(1.6, 1.4, 1.4), base * CF(0, 5.8, 0), skin, { name = "Head" })
	Build.ball(m, V(0.22, 0.22, 0.1), base * CF(-0.3, 5.9, -0.68), rgb(30, 24, 30), { name = "Eye" })
	Build.ball(m, V(0.22, 0.22, 0.1), base * CF(0.3, 5.9, -0.68), rgb(30, 24, 30), { name = "Eye" })
	Build.block(m, V(1.7, 0.4, 1.5), base * CF(0, 6.6, 0), shirt, { name = "Cap" })
	Build.block(m, V(1.2, 0.15, 0.8), base * CF(0, 6.45, -1), shirt, { name = "Brim" })
	GearModels.equip(m, vacuumTier, bagTier)
	for i, id in critters do
		local golden = string.sub(id, 1, 7) == "golden:"
		local critterId = if golden then string.sub(id, 8) else id
		local offset = ({ V(-3.2, 0, 3.6), V(3.2, 0, 3.6), V(0, 0, 6) })[i] or V(0, 0, 8)
		CritterModels.build(critterId, golden, parent, base * CF(offset), 0.8)
	end
	return m
end

local actors = ClientEnv.Instance.new("Folder")
character(actors, CF(z1 - 5, 0.2, 20) * roblox.CFrame.Angles(0, math.rad(200), 0), rgb(70, 160, 255), 6, 5, { "fox", "golden:squirrel", "hedgehog" })
character(actors, CF(z1 + 14, 0.2, 14) * roblox.CFrame.Angles(0, math.rad(150), 0), rgb(255, 120, 150), 4, 3, { "squirrel", "crow" })
character(actors, CF(z1 - 22, 0.2, 34) * roblox.CFrame.Angles(0, math.rad(230), 0), rgb(120, 220, 120), 9, 8, { "golden:fox", "owl", "bunny" })

-- critter parade for the collection shot, on a platform far from the map
local parade = ClientEnv.Instance.new("Folder")
local paradeOrigin = V(0, 0, 600)
Build.block(parade, V(90, 1, 40), CF(paradeOrigin.X, -0.5, paradeOrigin.Z), rgb(150, 205, 110), { name = "Stage", material = roblox.Enum.Material.Grass })
local list = {}
for _, critter in Critters.List do
	table.insert(list, critter)
end
for i, critter in list do
	local col = (i - 1) % 9
	local row = (i - 1) // 9
	local base = CF(paradeOrigin.X - 32 + col * 8, 0, paradeOrigin.Z - 10 + row * 9) * roblox.CFrame.Angles(0, math.rad((col - 4) * -6), 0)
	CritterModels.build(critter.id, i % 7 == 0, parade, base, 1.2)
end

---------------------------------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------------------------------

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function kindOf(part)
	if part.ClassName == "WedgePart" then
		return "wedge"
	end
	if part:FindFirstChildOfClass("SpecialMesh") then
		return "sphere"
	end
	local shape = part.Shape
	if shape == roblox.Enum.PartType.Ball then
		return "sphere"
	elseif shape == roblox.Enum.PartType.Cylinder then
		return "cylinder"
	end
	return "block"
end

local function collect(roots, filter)
	local parts = {}
	for _, root in roots do
		local real = ClientEnv.unwrap(root)
		for _, d in real:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.99 then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
				local huge = math.max(d.Size.X, d.Size.Z) > 400
				if not filter or huge or filter(x, y, z) then
					local c = d.Color
					table.insert(parts, {
						k = kindOf(d),
						s = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
						p = { round(x), round(y), round(z) },
						r = { round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22) },
						c = { round(c.R), round(c.G), round(c.B) },
						m = d.Material.Name,
						t = round(d.Transparency),
						rf = round(d.Reflectance),
					})
				end
			end
		end
	end
	return parts
end

local debrisRoot = env.workspace:FindFirstChild("DebrisVisuals")
local scenes = {
	{
		name = "zone1_squad",
		roots = { worldRoot, debrisRoot, actors },
		filter = function(x, _y, z)
			return x > z1 - 140 and x < z1 + 140 and math.abs(z) < 220
		end,
		camera = { pos = { z1 - 18, 20, 58 }, target = { z1 - 4, 3, 16 }, fov = 55 },
		sky = { 0.62, 0.8, 0.95 },
	},
	{
		name = "thumb_squad",
		roots = { worldRoot, debrisRoot, actors },
		filter = function(x, _y, z)
			return x > z1 - 140 and x < z1 + 140 and math.abs(z) < 220
		end,
		camera = { pos = { z1 + 16, 13, 50 }, target = { z1 - 8, 3.5, 21 }, fov = 42 },
		sky = { 0.62, 0.8, 0.95 },
	},
	{
		name = "overview",
		roots = { worldRoot, debrisRoot },
		filter = function(x, _y, z)
			return x < 760 and math.abs(z) < 260
		end,
		camera = { pos = { -40, 150, 190 }, target = { 250, 0, -10 }, fov = 50 },
		sky = { 0.62, 0.8, 0.95 },
	},
	{
		name = "hub",
		roots = { worldRoot },
		filter = function(x, _y, z)
			return x < 140 and math.abs(z) < 200
		end,
		camera = { pos = { 70, 45, 85 }, target = { -5, 4, -5 }, fov = 55 },
		sky = { 0.62, 0.8, 0.95 },
	},
	{
		name = "beach_golden",
		roots = { worldRoot, debrisRoot },
		filter = function(x, _y, z)
			local c = ZoneLayout.center(4)
			return x > c - 150 and x < c + 150 and math.abs(z) < 220
		end,
		camera = { pos = { ZoneLayout.center(4) - 70, 40, 75 }, target = { ZoneLayout.center(4), 0, 0 }, fov = 55 },
		sky = { 0.6, 0.82, 0.98 },
	},
	{
		name = "candy",
		roots = { worldRoot, debrisRoot },
		filter = function(x, _y, z)
			local c = ZoneLayout.center(6)
			return x > c - 150 and x < c + 150 and math.abs(z) < 220
		end,
		camera = { pos = { ZoneLayout.center(6) - 60, 38, 80 }, target = { ZoneLayout.center(6), 0, 0 }, fov = 55 },
		sky = { 0.98, 0.8, 0.9 },
	},
	{
		name = "volcano",
		roots = { worldRoot, debrisRoot },
		filter = function(x, _y, z)
			local c = ZoneLayout.center(7)
			return x > c - 150 and x < c + 150 and math.abs(z) < 220
		end,
		camera = { pos = { ZoneLayout.center(7) - 60, 40, 80 }, target = { ZoneLayout.center(7), 0, 0 }, fov = 55 },
		sky = { 0.95, 0.72, 0.6 },
	},
	{
		name = "critters",
		roots = { parade },
		camera = { pos = { 0, 22, 560 }, target = { 0, 1.5, 603 }, fov = 50 },
		sky = { 0.98, 0.9, 0.78 },
	},
}

fs.writeDir("tools/preview/scenes")
for _, scene in scenes do
	local parts = collect(scene.roots, scene.filter)
	local json = serde.encode("json", { parts = parts, camera = scene.camera, sky = scene.sky })
	fs.writeFile("tools/preview/scenes/" .. scene.name .. ".json", json)
	print(string.format("exported %-14s %5d parts", scene.name, #parts))
end
