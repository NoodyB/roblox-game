--!nocheck
-- Economy simulation for balancing. Models an active free-to-play player using the real config
-- and formulas (Stats/Economy), and prints when each milestone is reached.
--
--   lune run tools/simulate_economy.luau            -- default player
--   lune run tools/simulate_economy.luau -- vip      -- with 2x Coins + VIP passes
--
-- Model assumptions (documented in docs/Games/Sweep Squad/Economy Balance.md):
--  * Collection rate is limited by how many cells the vacuum covers per tick (power-limited) and by
--    how fast fresh debris is walked over (sweep-limited), times an EFFICIENCY factor (<1) for
--    already-cleaned areas, zig-zagging and pauses.
--  * Each bag trip also costs a round-trip walk to a sell pad.
--  * The player buys whatever upgrade is cheapest (including the next zone), and rebirths as soon
--    as it is affordable once zone 4+ is unlocked.

local process = require("@lune/process")
local Harness = require("../tests/harness")
Harness.reset()

local R = function(path)
	return Harness.requirePath("ReplicatedStorage.Shared." .. path)
end
local GameConfig = R("Config.GameConfig")
local Zones = R("Config.Zones")
local Upgrades = R("Config.Upgrades")
local DataSchema = R("Logic.DataSchema")
local Stats = R("Logic.Stats")
local Economy = R("Logic.Economy")
local Format = R("Util.Format")

local vip = process.args[1] == "vip"

-- Optional tuning overrides for fast iteration: TUNE_ZONE="1500,32000,..." etc.
local function list(name)
	local raw = process.env[name]
	if not raw then
		return nil
	end
	local out = {}
	for n in string.gmatch(raw, "[^,]+") do
		table.insert(out, tonumber(n))
	end
	return out
end
local zoneCosts = list("TUNE_ZONE")
if zoneCosts then
	for i, c in zoneCosts do
		Zones[i + 1].unlockCost = c
	end
end
local tierScale = tonumber(process.env.TUNE_TIER_GROWTH or "")
if tierScale then
	for _, track in { "Vacuums", "Bags", "Boots" } do
		for i, tier in Upgrades[track] do
			tier.cost = math.floor(tier.cost * tierScale ^ (i - 1))
		end
	end
end
local Progression = R("Config.Progression")
if process.env.TUNE_REBIRTH_BASE then
	Progression.Rebirth.BaseCost = tonumber(process.env.TUNE_REBIRTH_BASE)
end
if process.env.TUNE_REBIRTH_GROWTH then
	Progression.Rebirth.CostGrowth = tonumber(process.env.TUNE_REBIRTH_GROWTH)
end
local EFFICIENCY = 0.45
local SELL_DISTANCE = 45 -- average studs from the collecting area to a sell pad
local TRIP_OVERHEAD = 1.5 -- seconds lost per trip (turning, UI, etc.)
local MAX_HOURS = 60

local profile = DataSchema.new(0)
local passes = if vip then { DoubleCoins = true, VIP = true } else {}
-- Assume the player picks up a typical critter loadout over time (zone-appropriate commons).
local function critterBonusFor(maxZone)
	return math.min(0.08 * maxZone, 0.6)
end

local function rate(stats)
	local reach = stats.radius + GameConfig.CellReachPadding
	local cellArea = GameConfig.CellSize * GameConfig.CellSize
	local cellsInRadius = math.pi * reach * reach / cellArea
	local powerLimited = cellsInRadius * math.min(stats.power, GameConfig.CellMax) / GameConfig.CollectTickRate
	local sweepLimited = 2 * reach * stats.walkSpeed * GameConfig.CellMax / cellArea
	return math.min(powerLimited, sweepLimited) * EFFICIENCY
end

local t = 0
local milestones = {}
local function mark(name)
	if not milestones[name] then
		milestones[name] = t
		print(string.format("%8s  %-34s coins/min now: %s", Format.time(t), name, Format.abbreviate(milestones._cpm or 0)))
	end
end

local function tryBuy()
	local bought = true
	while bought do
		bought = false
		local options = {}
		for _, track in { "Vacuums", "Bags", "Boots" } do
			local tier = Economy.nextTier(profile, track)
			if tier then
				table.insert(options, { cost = tier.cost, kind = "tier", track = track })
			end
		end
		local nextZone = Zones[profile.maxZone + 1]
		if nextZone then
			table.insert(options, { cost = nextZone.unlockCost * 0.8, realCost = nextZone.unlockCost, kind = "zone" })
		end
		table.sort(options, function(a, b)
			return a.cost < b.cost
		end)
		local choice = options[1]
		if choice then
			local price = choice.realCost or choice.cost
			if profile.coins >= price then
				if choice.kind == "zone" then
					Economy.unlockZone(profile, profile.maxZone + 1)
					mark(string.format("Unlock zone %d (%s)", profile.maxZone, Zones[profile.maxZone].name))
				else
					Economy.buyNextTier(profile, choice.track)
				end
				bought = true
			end
		end
	end
end

print(if vip then "Simulating VIP + 2x Coins player" else "Simulating free-to-play player")
print(string.rep("-", 72))
while t < MAX_HOURS * 3600 do
	profile.equipped = {}
	local stats = Stats.compute(profile, { passes = passes })
	stats.coinMultiplier *= (1 + critterBonusFor(profile.maxZone))
	local zone = Zones[profile.maxZone]
	local collectTime = stats.capacity / rate(stats)
	local tripTime = collectTime + 2 * SELL_DISTANCE / stats.walkSpeed + TRIP_OVERHEAD
	local coins = Economy.sellValue(stats.capacity * zone.unitValue, stats.coinMultiplier)
	milestones._cpm = coins / tripTime * 60
	t += tripTime
	profile.coins += coins
	profile.stats.lifetimeCoins += coins
	tryBuy()
	if profile.vacuumTier == #Upgrades.Vacuums then
		mark("Max vacuum tier")
	end
	if profile.maxZone >= 4 and profile.coins >= Economy.rebirthCost(profile.rebirths) then
		Economy.rebirth(profile)
		mark("Rebirth #" .. profile.rebirths)
		if profile.rebirths >= 8 then
			break
		end
	end
end
print(string.rep("-", 72))
print(string.format("Simulated %s of active play", Format.time(t)))
