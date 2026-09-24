--!strict
-- Critter drop rolls, inventory changes, golden merging and equip validation.
-- Critters are only obtained through free gameplay drops (never sold for Robux).

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Critters = require(Shared.Config.Critters)
local Stats = require(script.Parent.Stats)

local CritterLogic = {}

-- Probability of each species given that a find happens in `zoneId` (sums to 1).
function CritterLogic.odds(zoneId: number): { { critter: Critters.Critter, chance: number } }
	local list = Critters.ByZone[zoneId] or {}
	local total = 0
	for _, critter in list do
		total += critter.weight
	end
	local result = {}
	for _, critter in list do
		table.insert(result, { critter = critter, chance = if total > 0 then critter.weight / total else 0 })
	end
	return result
end

-- Chance that a single collecting tick produces a find.
function CritterLogic.findChance(findMultiplier: number): number
	return math.min(1, GameConfig.CritterBaseFindChance * findMultiplier)
end

-- random: () -> [0, 1). Returns a species id or nil.
-- `eventCritters`/`eventShare`: during a seasonal event, that share of finds come from its critters.
function CritterLogic.roll(
	random: () -> number,
	zoneId: number,
	findMultiplier: number,
	ticksSinceLast: number,
	neverFound: boolean,
	eventCritters: { Critters.Critter }?,
	eventShare: number?
): string?
	local guaranteed = ticksSinceLast >= GameConfig.CritterPityTicks
		or (neverFound and ticksSinceLast >= GameConfig.FirstCritterGuaranteeTicks)
	if not guaranteed and random() >= CritterLogic.findChance(findMultiplier) then
		return nil
	end
	local list = Critters.ByZone[zoneId]
	if eventCritters and #eventCritters > 0 and not neverFound and random() < (eventShare or 0) then
		list = eventCritters
	end
	if not list or #list == 0 then
		return nil
	end
	local total = 0
	for _, critter in list do
		total += critter.weight
	end
	local pick = random() * total
	for _, critter in list do
		pick -= critter.weight
		if pick < 0 then
			return critter.id
		end
	end
	return list[#list].id
end

function CritterLogic.add(data: any, id: string, amount: number?)
	local entry = data.critters[id]
	if not entry then
		entry = { count = 0, golden = 0 }
		data.critters[id] = entry
	end
	entry.count += amount or 1
	data.discovered[id] = true
end

function CritterLogic.makeGolden(data: any, id: string): (boolean, string?)
	local entry = data.critters[id]
	if not Critters.ById[id] or not entry then
		return false, "You don't have that critter"
	end
	local needed = GameConfig.GoldenCost
	-- copies that are currently equipped cannot be consumed
	local equippedNormal = 0
	for _, e in data.equipped do
		local eid, golden = Stats.parseEquipped(e)
		if eid == id and not golden then
			equippedNormal += 1
		end
	end
	if entry.count - equippedNormal < needed then
		return false, string.format("Need %d unequipped copies", needed)
	end
	entry.count -= needed
	entry.golden += 1
	return true, nil
end

-- Validates and applies a full equip list. Entries are "id" or "golden:id".
function CritterLogic.setEquipped(data: any, list: { any }, slots: number): (boolean, string?)
	if type(list) ~= "table" then
		return false, "Invalid list"
	end
	if #list > slots then
		return false, "Not enough slots"
	end
	local usedNormal: { [string]: number } = {}
	local usedGolden: { [string]: number } = {}
	local clean = {}
	for _, entry in list do
		if type(entry) ~= "string" or #entry > 40 then
			return false, "Invalid critter"
		end
		local id, golden = Stats.parseEquipped(entry)
		local owned = data.critters[id]
		if not Critters.ById[id] or not owned then
			return false, "You don't own that critter"
		end
		if golden then
			usedGolden[id] = (usedGolden[id] or 0) + 1
			if usedGolden[id] > owned.golden then
				return false, "Not enough golden copies"
			end
		else
			usedNormal[id] = (usedNormal[id] or 0) + 1
			if usedNormal[id] > owned.count then
				return false, "Not enough copies"
			end
		end
		table.insert(clean, entry)
	end
	data.equipped = clean
	return true, nil
end

-- Score used to auto-equip the best critters.
function CritterLogic.score(id: string, golden: boolean): number
	local critter = Critters.ById[id]
	if not critter then
		return 0
	end
	local weights = { coins = 100, capacity = 60, radius = 25, speed = 12, find = 30 }
	return critter.value * (weights[critter.bonus] or 1) * (if golden then GameConfig.GoldenBonusMultiplier else 1)
end

-- Picks the best `slots` owned critters (golden copies count separately).
function CritterLogic.bestLoadout(data: any, slots: number): { string }
	local candidates = {}
	for id, owned in data.critters do
		for _ = 1, math.min(owned.golden, slots) do
			table.insert(candidates, { entry = "golden:" .. id, score = CritterLogic.score(id, true) })
		end
		for _ = 1, math.min(owned.count, slots) do
			table.insert(candidates, { entry = id, score = CritterLogic.score(id, false) })
		end
	end
	table.sort(candidates, function(a, b)
		if a.score == b.score then
			return a.entry < b.entry
		end
		return a.score > b.score
	end)
	local result = {}
	for i = 1, math.min(slots, #candidates) do
		table.insert(result, candidates[i].entry)
	end
	return result
end

return CritterLogic
