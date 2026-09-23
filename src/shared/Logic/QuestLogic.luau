--!strict
-- Daily quests (3 per UTC day, deterministic per player/day) and the 7-day login streak.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Config.Progression)
local Rng = require(Shared.Util.Rng)
local Economy = require(script.Parent.Economy)

local QuestLogic = {}

local TEMPLATE_BY_ID = {}
for _, template in Progression.QuestTemplates do
	TEMPLATE_BY_ID[template.id] = template
end
QuestLogic.TemplateById = TEMPLATE_BY_ID

function QuestLogic.dayIndex(unixTime: number): number
	return math.floor(unixTime / 86400)
end

function QuestLogic.secondsUntilReset(unixTime: number): number
	return 86400 - (math.floor(unixTime) % 86400)
end

local function scaledTarget(template, data): number
	if template.scale == "zone" then
		local zoneFactor = 1 + 0.6 * (data.maxZone - 1)
		return math.floor(template.target * zoneFactor / 10 + 0.5) * 10
	elseif template.scale == "coins" then
		local zone = Zones[data.maxZone] or Zones[1]
		local raw = template.target * zone.unitValue * (1 + data.rebirths * 0.5)
		-- round to 2 significant digits for friendly numbers
		local magnitude = 10 ^ math.max(0, math.floor(math.log10(math.max(raw, 1))) - 1)
		return math.max(1, math.floor(raw / magnitude + 0.5) * magnitude)
	end
	return template.target
end

function QuestLogic.generate(day: number, userId: number, data: any): { any }
	local rng = Rng.new(day * 1_000_003 + (userId % 1_000_000))
	local pool = table.clone(Progression.QuestTemplates)
	rng:shuffle(pool)
	local chosen = {}
	local usedStats = {}
	for _, template in pool do
		if #chosen >= GameConfig.DailyQuestCount then
			break
		end
		-- avoid two quests tracking the same stat on the same day
		if not usedStats[template.stat] then
			usedStats[template.stat] = true
			table.insert(chosen, {
				id = template.id,
				target = scaledTarget(template, data),
				progress = 0,
				claimed = false,
			})
		end
	end
	return chosen
end

-- Regenerates quests when the UTC day changes. Returns true if new quests were created.
function QuestLogic.ensureToday(data: any, now: number, userId: number): boolean
	local day = QuestLogic.dayIndex(now)
	if data.quests.day == day and #data.quests.list > 0 then
		return false
	end
	data.quests.day = day
	data.quests.list = QuestLogic.generate(day, userId, data)
	data.quests.bonusClaimed = false
	return true
end

-- Adds progress to every unclaimed quest tracking `stat`. Returns indices that just completed.
function QuestLogic.addProgress(data: any, stat: string, amount: number): { number }
	local completed = {}
	if amount <= 0 then
		return completed
	end
	for index, quest in data.quests.list do
		local template = TEMPLATE_BY_ID[quest.id]
		if template and template.stat == stat and not quest.claimed and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + amount)
			if quest.progress >= quest.target then
				table.insert(completed, index)
			end
		end
	end
	return completed
end

-- Claims a finished quest. Returns (ok, coinsAwarded or error, tokensAwarded)
function QuestLogic.claim(data: any, index: number): (boolean, any, number)
	local quest = data.quests.list[index]
	if type(index) ~= "number" or not quest then
		return false, "Unknown quest", 0
	end
	if quest.claimed then
		return false, "Already claimed", 0
	end
	if quest.progress < quest.target then
		return false, "Quest not finished", 0
	end
	local template = TEMPLATE_BY_ID[quest.id]
	local coins = Economy.questReward(data, if template then template.reward else 1)
	quest.claimed = true
	data.coins += coins
	data.stats.lifetimeCoins += coins

	local tokens = 0
	local allDone = true
	for _, q in data.quests.list do
		if not q.claimed then
			allDone = false
			break
		end
	end
	if allDone and not data.quests.bonusClaimed then
		data.quests.bonusClaimed = true
		if data.rebirths > 0 then
			tokens = Progression.AllQuestsTokenReward
			data.rebirthTokens += tokens
		end
	end
	return true, coins, tokens
end

-- Updates the streak for today's login. Returns true if a reward is waiting to be claimed.
function QuestLogic.updateStreak(data: any, now: number): boolean
	local day = QuestLogic.dayIndex(now)
	local streak = data.streak
	if streak.lastDay ~= day then
		if streak.lastDay == day - 1 then
			streak.count = (streak.count % GameConfig.StreakLength) + 1
		else
			streak.count = 1
		end
		streak.lastDay = day
	end
	return streak.claimedDay ~= day
end

function QuestLogic.streakReward(data: any): (number, number)
	local dayInCycle = math.clamp(data.streak.count, 1, GameConfig.StreakLength)
	local units = Progression.StreakRewards[dayInCycle] or 1
	local boostSeconds = if dayInCycle == GameConfig.StreakLength then Progression.StreakDay7BoostSeconds else 0
	return Economy.questReward(data, units), boostSeconds
end

function QuestLogic.claimStreak(data: any, now: number): (boolean, any, number)
	local day = QuestLogic.dayIndex(now)
	if data.streak.lastDay ~= day then
		QuestLogic.updateStreak(data, now)
	end
	if data.streak.claimedDay == day then
		return false, "Come back tomorrow!", 0
	end
	local coins, boostSeconds = QuestLogic.streakReward(data)
	data.streak.claimedDay = day
	data.coins += coins
	data.stats.lifetimeCoins += coins
	if boostSeconds > 0 then
		data.boosts.coins2x += boostSeconds
	end
	return true, coins, boostSeconds
end

return QuestLogic
