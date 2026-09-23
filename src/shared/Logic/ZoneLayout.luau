--!strict
-- Deterministic world geometry shared by server (collection, map building) and client (rendering).
-- Everything here is plain numbers so it runs identically in Roblox and in offline tests.
--
-- Layout: the hub is centered at X = 0. Zone k is centered at X = k * ZoneSpacing, all on Z = 0.
-- Each zone is a walled square with a gate opening on its west wall and an exit on its east wall.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Rng = require(Shared.Util.Rng)

local ZoneLayout = {}

export type Prop = { kind: string, x: number, z: number, rotation: number, radius: number, scale: number }

type PropDef = { kind: string, radius: number, weight: number }

local PROP_SETS: { [string]: { PropDef } } = {
	suburb = {
		{ kind = "autumnTree", radius = 5, weight = 4 },
		{ kind = "bush", radius = 3, weight = 2 },
		{ kind = "bench", radius = 3.5, weight = 1 },
		{ kind = "lamp", radius = 1.5, weight = 1 },
		{ kind = "rock", radius = 3, weight = 1 },
	},
	farm = {
		{ kind = "pumpkin", radius = 3, weight = 3 },
		{ kind = "haybale", radius = 3.5, weight = 2 },
		{ kind = "autumnTree", radius = 5, weight = 2 },
		{ kind = "scarecrow", radius = 2.5, weight = 1 },
	},
	forest = {
		{ kind = "pine", radius = 4.5, weight = 5 },
		{ kind = "stump", radius = 2.5, weight = 2 },
		{ kind = "rock", radius = 3, weight = 1 },
		{ kind = "mushroom", radius = 2, weight = 2 },
	},
	beach = {
		{ kind = "palm", radius = 3.5, weight = 3 },
		{ kind = "umbrella", radius = 3, weight = 2 },
		{ kind = "rock", radius = 3, weight = 1 },
		{ kind = "sandcastle", radius = 3, weight = 1 },
	},
	snow = {
		{ kind = "snowPine", radius = 4.5, weight = 4 },
		{ kind = "snowman", radius = 2.5, weight = 2 },
		{ kind = "iceRock", radius = 3, weight = 2 },
	},
	candy = {
		{ kind = "lollipop", radius = 2.5, weight = 3 },
		{ kind = "candyCane", radius = 2, weight = 2 },
		{ kind = "gumdrop", radius = 3.5, weight = 2 },
	},
	volcano = {
		{ kind = "lavaRock", radius = 3.5, weight = 3 },
		{ kind = "vent", radius = 3, weight = 2 },
		{ kind = "crystal", radius = 2.5, weight = 2 },
	},
	moon = {
		{ kind = "moonRock", radius = 3.5, weight = 3 },
		{ kind = "antenna", radius = 2, weight = 1 },
		{ kind = "rocket", radius = 4, weight = 1 },
		{ kind = "crystal", radius = 2.5, weight = 2 },
	},
}
ZoneLayout.PropSets = PROP_SETS

local PROPS_PER_ZONE = 10
local PATH_HALF_WIDTH = 10
local SELL_PAD_OFFSET = 54 -- distance from zone center along X
local PAD_MASK_RADIUS = 11

function ZoneLayout.cellsPerSide(): number
	return math.floor(GameConfig.DebrisAreaSize / GameConfig.CellSize)
end

function ZoneLayout.center(zoneId: number): (number, number)
	return zoneId * GameConfig.ZoneSpacing, 0
end

function ZoneLayout.bounds(zoneId: number): (number, number, number, number)
	local cx, cz = ZoneLayout.center(zoneId)
	local half = (if zoneId == 0 then GameConfig.HubSize else GameConfig.ZoneSize) / 2
	return cx - half, cx + half, cz - half, cz + half
end

-- Returns originX, originZ (min corner of the debris area), cols, rows
function ZoneLayout.debrisArea(zoneId: number): (number, number, number, number)
	local cx, cz = ZoneLayout.center(zoneId)
	local n = ZoneLayout.cellsPerSide()
	local size = n * GameConfig.CellSize
	return cx - size / 2, cz - size / 2, n, n
end

function ZoneLayout.gatePosition(zoneId: number): (number, number)
	local minX = ZoneLayout.bounds(zoneId)
	return minX, 0
end

function ZoneLayout.sellPads(zoneId: number): { { x: number, z: number } }
	local cx, cz = ZoneLayout.center(zoneId)
	return {
		{ x = cx - SELL_PAD_OFFSET, z = cz },
		{ x = cx + SELL_PAD_OFFSET, z = cz },
	}
end

-- Where players arrive when teleporting to a zone (just inside the gate).
function ZoneLayout.spawnPoint(zoneId: number): (number, number)
	if zoneId == 0 then
		return -22, 0
	end
	local minX = ZoneLayout.bounds(zoneId)
	return minX + 8, 0
end

-- 0 = hub, 1..#Zones = zone, nil = corridor / outside
function ZoneLayout.zoneAt(x: number, z: number): number?
	local half = GameConfig.HubSize / 2
	if math.abs(x) <= half and math.abs(z) <= half then
		return 0
	end
	local spacing = GameConfig.ZoneSpacing
	local k = math.floor(x / spacing + 0.5)
	if k < 1 or k > #Zones then
		return nil
	end
	local minX, maxX, minZ, maxZ = ZoneLayout.bounds(k)
	if x >= minX and x <= maxX and z >= minZ and z <= maxZ then
		return k
	end
	return nil
end

local propCache: { [number]: { Prop } } = {}

function ZoneLayout.props(zoneId: number): { Prop }
	local cached = propCache[zoneId]
	if cached then
		return cached
	end
	local zone = Zones[zoneId]
	local set = PROP_SETS[zone.theme.props] or PROP_SETS.suburb
	local totalWeight = 0
	for _, def in set do
		totalWeight += def.weight
	end

	local rng = Rng.new(1000 + zoneId * 7919)
	local cx, cz = ZoneLayout.center(zoneId)
	local halfArea = GameConfig.DebrisAreaSize / 2
	local pads = ZoneLayout.sellPads(zoneId)
	local props: { Prop } = {}
	local attempts = 0
	while #props < PROPS_PER_ZONE and attempts < 400 do
		attempts += 1
		-- weighted pick
		local roll = rng:next() * totalWeight
		local def = set[1]
		for _, candidate in set do
			roll -= candidate.weight
			if roll <= 0 then
				def = candidate
				break
			end
		end
		local margin = def.radius + 3
		local x = cx + rng:range(-halfArea + margin, halfArea - margin)
		local z = cz + rng:range(-halfArea + margin, halfArea - margin)
		local ok = math.abs(z - cz) > PATH_HALF_WIDTH + def.radius
		if ok then
			for _, pad in pads do
				local dx, dz = x - pad.x, z - pad.z
				if dx * dx + dz * dz < (14 + def.radius) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, other in props do
				local dx, dz = x - other.x, z - other.z
				local minDist = def.radius + other.radius + 6
				if dx * dx + dz * dz < minDist * minDist then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(props, {
				kind = def.kind,
				x = x,
				z = z,
				rotation = rng:range(0, 360),
				radius = def.radius,
				scale = rng:range(0.9, 1.2),
			})
		end
	end
	propCache[zoneId] = props
	return props
end

local maskCache: { [number]: { [number]: boolean } } = {}

-- Set of 0-based cell indices that never hold debris (under props and sell pads).
function ZoneLayout.mask(zoneId: number): { [number]: boolean }
	local cached = maskCache[zoneId]
	if cached then
		return cached
	end
	local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
	local size = GameConfig.CellSize
	local blockers = {}
	for _, prop in ZoneLayout.props(zoneId) do
		table.insert(blockers, { x = prop.x, z = prop.z, r = prop.radius + 1 })
	end
	for _, pad in ZoneLayout.sellPads(zoneId) do
		table.insert(blockers, { x = pad.x, z = pad.z, r = PAD_MASK_RADIUS })
	end
	local mask = {}
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x = originX + (col + 0.5) * size
			local z = originZ + (row + 0.5) * size
			for _, b in blockers do
				local dx, dz = x - b.x, z - b.z
				if dx * dx + dz * dz <= b.r * b.r then
					mask[row * cols + col] = true
					break
				end
			end
		end
	end
	maskCache[zoneId] = mask
	return mask
end

return ZoneLayout
