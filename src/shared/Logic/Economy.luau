--!strict
-- Pure economy rules: prices, rewards, rebirth requirements and purchase validation.
-- All mutation helpers return (ok, errorMessage) and only change `data` when ok is true.

local Shared = script.Parent.Parent
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Config.Progression)
local Codes = require(Shared.Config.Codes)
local Format = require(Shared.Util.Format)
local Critters = require(Shared.Config.Critters)
local Stats = require(script.Parent.Stats)

local Economy = {}

local TRACK_FIELD = {
	Vacuums = "vacuumTier",
	Bags = "bagTier",
	Boots = "bootsTier",
}
Economy.TrackField = TRACK_FIELD

function Economy.bestZone(data: any)
	return Zones[data.maxZone] or Zones[1]
end

-- Coins a full sale is worth. `bagValue` already contains zone value and squad/golden bonuses.
function Economy.sellValue(bagValue: number, coinMultiplier: number): number
	return math.floor(bagValue * coinMultiplier + 0.5)
end

function Economy.nextTier(data: any, track: string)
	local field = TRACK_FIELD[track]
	if not field then
		return nil
	end
	local list = (Upgrades :: any)[track]
	return list[data[field] + 1], data[field] + 1
end

function Economy.buyNextTier(data: any, track: string): (boolean, string?)
	local field = TRACK_FIELD[track]
	if not field then
		return false, "Unknown upgrade"
	end
	local tier, index = Economy.nextTier(data, track)
	if not tier then
		return false, "Already maxed out!"
	end
	if data.coins < tier.cost then
		return false, "Not enough coins"
	end
	data.coins -= tier.cost
	data[field] = index
	return true, nil
end

function Economy.canUnlockZone(data: any, zoneId: number): (boolean, string?)
	local zone = Zones[zoneId]
	if not zone then
		return false, "Unknown zone"
	end
	if zoneId <= data.maxZone then
		return false, "Already unlocked"
	end
	if zoneId ~= data.maxZone + 1 then
		return false, "Unlock the previous zone first"
	end
	if data.coins < zone.unlockCost then
		return false, "Not enough coins"
	end
	return true, nil
end

function Economy.unlockZone(data: any, zoneId: number): (boolean, string?)
	local ok, err = Economy.canUnlockZone(data, zoneId)
	if not ok then
		return false, err
	end
	data.coins -= Zones[zoneId].unlockCost
	data.maxZone = zoneId
	return true, nil
end

function Economy.rebirthCost(rebirths: number): number
	local cfg = Progression.Rebirth
	return math.floor(cfg.BaseCost * cfg.CostGrowth ^ rebirths)
end

function Economy.rebirthTokens(nextRebirthNumber: number): number
	local cfg = Progression.Rebirth
	local tokens = cfg.TokensPerRebirth
	if nextRebirthNumber % cfg.BonusTokenEvery == 0 then
		tokens += 1
	end
	return tokens
end

-- Performs a rebirth. Keeps critters, perks, stats, settings, quests, receipts and boosts.
function Economy.rebirth(data: any): (boolean, string?)
	local cost = Economy.rebirthCost(data.rebirths)
	if data.coins < cost then
		return false, "Not enough coins"
	end
	local headStart = Stats.perkLevel(data, "headStart")
	data.rebirths += 1
	data.rebirthTokens += Economy.rebirthTokens(data.rebirths)
	data.coins = 0
	data.bagUnits = 0
	data.bagValue = 0
	data.vacuumTier = math.min(1 + headStart, #Upgrades.Vacuums)
	data.bagTier = math.min(1 + headStart, #Upgrades.Bags)
	data.bootsTier = 1
	data.maxZone = 1
	return true, nil
end

function Economy.buyPerk(data: any, perkId: string): (boolean, string?)
	local perk = Progression.PerksById[perkId]
	if not perk then
		return false, "Unknown perk"
	end
	local level = data.perks[perkId] or 0
	if level >= perk.maxLevel then
		return false, "Perk is maxed"
	end
	if data.rebirthTokens < perk.costPerLevel then
		return false, "Not enough rebirth tokens"
	end
	data.rebirthTokens -= perk.costPerLevel
	data.perks[perkId] = level + 1
	return true, nil
end

-- One "income unit": roughly what an active player earns in a short while at their progression.
-- Used to scale quest, streak and coin-pack rewards so they stay meaningful all game long.
function Economy.incomeUnit(data: any): number
	local zone = Economy.bestZone(data)
	local capacity = Stats.compute(data).capacity
	local base = math.max(150 * zone.unitValue, capacity * zone.unitValue * 0.75)
	return math.floor(base * Stats.rebirthMultiplier(data.rebirths))
end

function Economy.questReward(data: any, rewardUnits: number): number
	return math.max(1, math.floor(Economy.incomeUnit(data) * rewardUnits))
end

-- Coin packs are sized in "bags of your best debris" so they are always worth the same amount of play.
function Economy.coinPackAmount(data: any, bags: number): number
	local zone = Economy.bestZone(data)
	local capacity = Stats.compute(data).capacity
	return math.floor(capacity * zone.unitValue * bags * Stats.rebirthMultiplier(data.rebirths))
end

function Economy.normalizeCode(raw: any): string?
	if type(raw) ~= "string" or #raw == 0 or #raw > 32 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	if not string.match(code, "^[%w_]+$") then
		return nil
	end
	return code
end

-- Redeems a promo code. Returns (ok, message).
function Economy.redeemCode(data: any, raw: any, now: number): (boolean, string)
	local code = Economy.normalizeCode(raw)
	local def = code and Codes[code]
	if not code or not def then
		return false, "That code doesn't exist"
	end
	if def.expires and now > def.expires then
		return false, "That code has expired"
	end
	if data.redeemedCodes[code] then
		return false, "You already used that code"
	end
	local message
	if def.reward == "coins" then
		local coins = Economy.coinPackAmount(data, def.bags or 1)
		data.coins += coins
		data.stats.lifetimeCoins += coins
		message = "+" .. Format.abbreviate(coins) .. " coins!"
	elseif def.reward == "boost" and def.boost and data.boosts[def.boost] ~= nil then
		data.boosts[def.boost] += def.seconds or 0
		message = "Boost activated!"
	elseif def.reward == "critter" and def.critter and Critters.ById[def.critter] then
		local entry = data.critters[def.critter]
		if not entry then
			entry = { count = 0, golden = 0 }
			data.critters[def.critter] = entry
		end
		entry.count += 1
		data.discovered[def.critter] = true
		message = Critters.ById[def.critter].name .. " joined your squad!"
	else
		return false, "That code can't be used right now"
	end
	data.redeemedCodes[code] = true
	return true, message
end

return Economy
