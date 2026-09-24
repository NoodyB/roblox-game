--!strict
-- Derives a player's effective gameplay stats from their profile, owned passes and active boosts.
-- Used by the server (authoritative) and by the client (display only).

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.Upgrades)
local Critters = require(Shared.Config.Critters)
local Progression = require(Shared.Config.Progression)
local Products = require(Shared.Config.Products)

local Stats = {}

export type Context = {
	passes: { [string]: boolean }?,
	storm: boolean?,
}

export type Result = {
	radius: number,
	power: number,
	capacity: number,
	walkSpeed: number,
	coinMultiplier: number,
	findMultiplier: number,
	equipSlots: number,
	rebirthMultiplier: number,
}

function Stats.parseEquipped(entry: string): (string, boolean)
	local golden = string.sub(entry, 1, 7) == "golden:"
	local id = if golden then string.sub(entry, 8) else entry
	return id, golden
end

function Stats.critterBonuses(equipped: { string }, slots: number): { [string]: number }
	local totals = { coins = 0, radius = 0, capacity = 0, speed = 0, find = 0 }
	for index, entry in equipped do
		if index > slots then
			break
		end
		local id, golden = Stats.parseEquipped(entry)
		local critter = Critters.ById[id]
		if critter then
			local value = critter.value * (if golden then GameConfig.GoldenBonusMultiplier else 1)
			totals[critter.bonus] += value
		end
	end
	return totals
end

function Stats.equipSlots(passes: { [string]: boolean }?): number
	local slots = GameConfig.BaseEquipSlots
	if passes and passes.CritterSlots then
		slots += GameConfig.PassEquipSlots
	end
	if passes and passes.VIP then
		slots += Products.VipExtraSlots
	end
	return slots
end

function Stats.perkLevel(data: any, id: string): number
	return (data.perks and data.perks[id]) or 0
end

function Stats.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Progression.Rebirth.MultiplierPerRebirth
end

function Stats.compute(data: any, ctx: Context?): Result
	local passes = (ctx and ctx.passes) or {}
	local vacuum = Upgrades.Vacuums[data.vacuumTier] or Upgrades.Vacuums[1]
	local bag = Upgrades.Bags[data.bagTier] or Upgrades.Bags[1]
	local boots = Upgrades.Boots[data.bootsTier] or Upgrades.Boots[1]
	local slots = Stats.equipSlots(passes)
	local bonus = Stats.critterBonuses(data.equipped or {}, slots)

	local perks = Progression.PerksById
	local goldenTouch = Stats.perkLevel(data, "goldenTouch") * perks.goldenTouch.value
	local deepPockets = Stats.perkLevel(data, "deepPockets") * perks.deepPockets.value
	local quickFeet = Stats.perkLevel(data, "quickFeet") * perks.quickFeet.value
	local whisperer = Stats.perkLevel(data, "whisperer") * perks.whisperer.value

	local collectBoost = data.boosts and data.boosts.collect2x > 0
	local coinBoost = data.boosts and data.boosts.coins2x > 0

	local radius = vacuum.radius + bonus.radius + (if collectBoost then 3 else 0)
	local power = vacuum.power * (if collectBoost then 2 else 1)
	local capacity = math.floor(bag.capacity * (1 + bonus.capacity + deepPockets))
	local walkSpeed = boots.speed + bonus.speed + quickFeet

	local rebirthMultiplier = Stats.rebirthMultiplier(data.rebirths or 0)
	local coinMultiplier = rebirthMultiplier * (1 + bonus.coins + goldenTouch)
	if passes.DoubleCoins then
		coinMultiplier *= Products.DoubleCoinsMultiplier
	end
	if passes.VIP then
		coinMultiplier *= Products.VipCoinMultiplier
	end
	if passes.GroupMember then
		coinMultiplier *= 1 + GameConfig.GroupBonus
	end
	if coinBoost then
		coinMultiplier *= 2
	end
	if ctx and ctx.storm then
		coinMultiplier *= Products.GoldenStormMultiplier
	end

	return {
		radius = radius,
		power = power,
		capacity = capacity,
		walkSpeed = walkSpeed,
		coinMultiplier = coinMultiplier,
		findMultiplier = 1 + bonus.find + whisperer,
		equipSlots = slots,
		rebirthMultiplier = rebirthMultiplier,
	}
end

return Stats
