--!strict
-- Player save data: default template, migrations and sanitization of untrusted/legacy data.
-- The server is the only writer. Clients only ever receive copies.

local Shared = script.Parent.Parent
local TableUtil = require(Shared.Util.TableUtil)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Critters = require(Shared.Config.Critters)
local Progression = require(Shared.Config.Progression)

local DataSchema = {}

DataSchema.VERSION = 1

export type QuestEntry = { id: string, target: number, progress: number, claimed: boolean }

export type Profile = {
	version: number,
	coins: number,
	bagUnits: number,
	bagValue: number,
	vacuumTier: number,
	bagTier: number,
	bootsTier: number,
	maxZone: number,
	rebirths: number,
	rebirthTokens: number,
	perks: { [string]: number },
	critters: { [string]: { count: number, golden: number } },
	discovered: { [string]: boolean },
	equipped: { string },
	quests: { day: number, list: { QuestEntry }, bonusClaimed: boolean },
	streak: { lastDay: number, count: number, claimedDay: number },
	boosts: { coins2x: number, collect2x: number },
	receipts: { string },
	stats: {
		lifetimeCoins: number,
		lifetimeUnits: number,
		sells: number,
		zoneClears: number,
		crittersFound: number,
		playSeconds: number,
		ticksSinceCritter: number,
		purchases: number,
	},
	settings: { music: boolean, sfx: boolean, lowGraphics: boolean, showCritters: boolean },
	tutorialStep: number,
	firstJoin: number,
	lastJoin: number,
}

local DEFAULT: Profile = {
	version = DataSchema.VERSION,
	coins = 0,
	bagUnits = 0,
	bagValue = 0,
	vacuumTier = 1,
	bagTier = 1,
	bootsTier = 1,
	maxZone = 1,
	rebirths = 0,
	rebirthTokens = 0,
	perks = {},
	critters = {},
	discovered = {},
	equipped = {},
	quests = { day = -1, list = {}, bonusClaimed = false },
	streak = { lastDay = -1, count = 0, claimedDay = -1 },
	boosts = { coins2x = 0, collect2x = 0 },
	receipts = {},
	stats = {
		lifetimeCoins = 0,
		lifetimeUnits = 0,
		sells = 0,
		zoneClears = 0,
		crittersFound = 0,
		playSeconds = 0,
		ticksSinceCritter = 0,
		purchases = 0,
	},
	settings = { music = true, sfx = true, lowGraphics = false, showCritters = true },
	tutorialStep = 1,
	firstJoin = 0,
	lastJoin = 0,
}

function DataSchema.new(now: number?): Profile
	local profile = TableUtil.deepCopy(DEFAULT)
	profile.firstJoin = now or 0
	profile.lastJoin = now or 0
	return profile
end

-- Version upgrades. Each step takes data at version N and returns data at version N + 1.
local MIGRATIONS: { [number]: (any) -> any } = {
	-- [1] = function(data) ...; data.version = 2; return data end,
}

local function finiteNumber(value: any, default: number, min: number?, max: number?): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	if min and value < min then
		return min
	end
	if max and value > max then
		return max
	end
	return value
end

local function int(value: any, default: number, min: number, max: number): number
	return math.floor(finiteNumber(value, default, min, max))
end

-- Accepts anything (nil, corrupted tables, old versions) and returns a valid current Profile.
function DataSchema.migrate(raw: any, now: number?): Profile
	if type(raw) ~= "table" then
		return DataSchema.new(now)
	end
	local data = raw
	local version = if type(data.version) == "number" then data.version else 1
	while MIGRATIONS[version] do
		data = MIGRATIONS[version](data)
		version += 1
	end
	data.version = DataSchema.VERSION
	TableUtil.reconcile(data, DEFAULT)
	return DataSchema.sanitize(data)
end

function DataSchema.sanitize(data: any): Profile
	data.coins = finiteNumber(data.coins, 0, 0)
	data.bagUnits = finiteNumber(data.bagUnits, 0, 0)
	data.bagValue = finiteNumber(data.bagValue, 0, 0)
	data.vacuumTier = int(data.vacuumTier, 1, 1, #Upgrades.Vacuums)
	data.bagTier = int(data.bagTier, 1, 1, #Upgrades.Bags)
	data.bootsTier = int(data.bootsTier, 1, 1, #Upgrades.Boots)
	data.maxZone = int(data.maxZone, 1, 1, #Zones)
	data.rebirths = int(data.rebirths, 0, 0, 1e6)
	data.rebirthTokens = int(data.rebirthTokens, 0, 0, 1e6)
	data.tutorialStep = int(data.tutorialStep, 1, 1, 100)

	-- perks: only known ids, clamped to max level
	local perks = {}
	if type(data.perks) == "table" then
		for id, level in data.perks do
			local perk = Progression.PerksById[id]
			if perk then
				perks[id] = int(level, 0, 0, perk.maxLevel)
			end
		end
	end
	data.perks = perks

	-- critters: only known species with sane counts
	local critters = {}
	if type(data.critters) == "table" then
		for id, entry in data.critters do
			if Critters.ById[id] and type(entry) == "table" then
				critters[id] = { count = int(entry.count, 0, 0, 1e6), golden = int(entry.golden, 0, 0, 1e6) }
			end
		end
	end
	data.critters = critters

	local discovered = {}
	if type(data.discovered) == "table" then
		for id, value in data.discovered do
			if Critters.ById[id] and value == true then
				discovered[id] = true
			end
		end
	end
	data.discovered = discovered

	local equipped = {}
	if type(data.equipped) == "table" then
		for _, entry in data.equipped do
			if type(entry) == "string" and #equipped < 16 then
				table.insert(equipped, entry)
			end
		end
	end
	data.equipped = equipped

	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	local receipts = {}
	for _, id in data.receipts do
		if type(id) == "string" then
			table.insert(receipts, id)
		end
	end
	data.receipts = receipts

	data.boosts.coins2x = finiteNumber(data.boosts.coins2x, 0, 0, 60 * 60 * 24 * 30)
	data.boosts.collect2x = finiteNumber(data.boosts.collect2x, 0, 0, 60 * 60 * 24 * 30)

	for key, value in DEFAULT.stats do
		data.stats[key] = finiteNumber(data.stats[key], value, 0)
	end
	for key, value in DEFAULT.settings do
		if type(data.settings[key]) ~= "boolean" then
			data.settings[key] = value
		end
	end

	if type(data.quests.list) ~= "table" then
		data.quests.list = {}
	end
	data.quests.day = int(data.quests.day, -1, -1, 1e9)
	data.quests.bonusClaimed = data.quests.bonusClaimed == true
	data.streak.lastDay = int(data.streak.lastDay, -1, -1, 1e9)
	data.streak.claimedDay = int(data.streak.claimedDay, -1, -1, 1e9)
	data.streak.count = int(data.streak.count, 0, 0, 1e6)

	return data :: Profile
end

-- Copy of the profile that is safe/cheap to send to the owning client.
function DataSchema.clientView(data: Profile): { [string]: any }
	local view = TableUtil.deepCopy(data) :: any
	view.receipts = nil
	return view
end

return DataSchema
