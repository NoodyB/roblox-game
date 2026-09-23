--!strict
-- Rebirths, rebirth perks, daily quests and the daily streak.

local Progression = {}

Progression.Rebirth = {
	BaseCost = 250_000,
	CostGrowth = 3.2,
	MultiplierPerRebirth = 0.5, -- additive coin multiplier per rebirth
	TokensPerRebirth = 1,
	BonusTokenEvery = 5, -- one extra token on every 5th rebirth
}

export type Perk = {
	id: string,
	name: string,
	emoji: string,
	description: string,
	maxLevel: number,
	costPerLevel: number,
	value: number,
}

Progression.Perks = {
	{ id = "goldenTouch", name = "Golden Touch", emoji = "✨", description = "+5% coins per level", maxLevel = 20, costPerLevel = 1, value = 0.05 },
	{ id = "deepPockets", name = "Deep Pockets", emoji = "🎒", description = "+10% bag size per level", maxLevel = 10, costPerLevel = 1, value = 0.1 },
	{ id = "quickFeet", name = "Quick Feet", emoji = "👟", description = "+1 walk speed per level", maxLevel = 4, costPerLevel = 2, value = 1 },
	{ id = "whisperer", name = "Critter Whisperer", emoji = "🐾", description = "+10% critter luck per level", maxLevel = 10, costPerLevel = 1, value = 0.1 },
	{ id = "headStart", name = "Head Start", emoji = "🚀", description = "Keep +1 vacuum & bag tier after rebirth per level", maxLevel = 3, costPerLevel = 3, value = 1 },
} :: { Perk }

Progression.PerksById = {} :: { [string]: Perk }
for _, perk in Progression.Perks do
	Progression.PerksById[perk.id] = perk
end

export type QuestTemplate = {
	id: string,
	stat: string,
	text: string,
	target: number,
	scale: string, -- "none" | "zone" | "coins"
	reward: number, -- reward in "income units" (see Economy.questReward)
}

-- Stats that quests can track. Keep in sync with QuestService hooks.
Progression.QuestStats = { "units", "sells", "coins", "critters", "clears", "goldenUnits", "minutes", "upgrades" }

Progression.QuestTemplates = {
	{ id = "collect_small", stat = "units", text = "Vacuum %s debris", target = 400, scale = "zone", reward = 1 },
	{ id = "collect_big", stat = "units", text = "Vacuum %s debris", target = 1500, scale = "zone", reward = 2.5 },
	{ id = "sell", stat = "sells", text = "Sell a full bag %s times", target = 10, scale = "none", reward = 1.5 },
	{ id = "earn", stat = "coins", text = "Earn %s coins", target = 600, scale = "coins", reward = 1.5 },
	{ id = "critter", stat = "critters", text = "Find %s critter", target = 1, scale = "none", reward = 2 },
	{ id = "clear", stat = "clears", text = "Help clear %s zone", target = 1, scale = "none", reward = 2 },
	{ id = "golden", stat = "goldenUnits", text = "Vacuum %s golden debris", target = 150, scale = "zone", reward = 2 },
	{ id = "play", stat = "minutes", text = "Clean for %s minutes", target = 12, scale = "none", reward = 1.5 },
	{ id = "upgrade", stat = "upgrades", text = "Buy %s upgrade", target = 1, scale = "none", reward = 1 },
} :: { QuestTemplate }

-- Completing every daily quest also awards this many rebirth tokens (only once rebirthed at least once).
Progression.AllQuestsTokenReward = 1

-- Daily login streak (7-day cycle). Rewards are in income units, except day 7 which also grants a boost.
Progression.StreakRewards = { 1, 1.5, 2, 2.5, 3, 4, 6 }
Progression.StreakDay7BoostSeconds = 15 * 60

return Progression
