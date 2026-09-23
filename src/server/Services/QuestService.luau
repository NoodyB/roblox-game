--!strict
-- Daily quests, the login streak and the new-player tutorial.
-- Progress is driven entirely by server events, so it cannot be spoofed by the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QuestLogic = require(Shared.Logic.QuestLogic)
local Format = require(Shared.Util.Format)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Events = require(script.Parent.Events)
local Analytics = require(script.Parent.Analytics)

local QuestService = {}

-- Tutorial steps (profile.tutorialStep). The client shows guidance for the current step.
QuestService.Tutorial = {
	COLLECT = 1, -- walk into leaves
	SELL = 2, -- sell at the compost bin
	UPGRADE = 3, -- buy an upgrade
	UNLOCK = 4, -- unlock the next zone
	DONE = 5,
}
local T = QuestService.Tutorial

local function advanceTutorial(player: Player, fromStep: number)
	local profile = DataService.get(player)
	if profile and profile.tutorialStep == fromStep then
		profile.tutorialStep = fromStep + 1
		PlayerService.markDirty(player)
	end
end

local function progress(player: Player, stat: string, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local completed = QuestLogic.addProgress(profile, stat, amount)
	if #completed > 0 then
		Net.notify(player, "success", "📜 Quest complete! Claim your reward in Quests.")
		Net.fire("Effect", player, "questDone", { count = #completed })
	end
	PlayerService.markDirty(player)
end

local function refreshDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	local changed = QuestLogic.ensureToday(profile, now, player.UserId)
	local streakReady = QuestLogic.updateStreak(profile, now)
	if changed or streakReady then
		PlayerService.markDirty(player)
	end
	if streakReady then
		Net.notify(player, "reward", string.format("🔥 Day %d streak reward is ready!", profile.streak.count))
	end
end

function QuestService:Init()
	DataService.ProfileLoaded:Connect(function(player)
		refreshDaily(player)
		Analytics.onboarding(player, "Joined")
	end)

	Events.Collected:Connect(function(player, units, _zoneId, golden)
		progress(player, "units", units)
		if golden then
			progress(player, "goldenUnits", units)
		end
		advanceTutorial(player, T.COLLECT)
	end)
	Events.Sold:Connect(function(player, coins)
		progress(player, "sells", 1)
		progress(player, "coins", coins)
		advanceTutorial(player, T.SELL)
	end)
	Events.ZoneCleared:Connect(function(player, _zoneId, _bonus)
		progress(player, "clears", 1)
	end)
	Events.CritterFound:Connect(function(player)
		progress(player, "critters", 1)
	end)
	Events.Upgraded:Connect(function(player)
		progress(player, "upgrades", 1)
		advanceTutorial(player, T.UPGRADE)
	end)
	Events.ZoneUnlocked:Connect(function(player)
		advanceTutorial(player, T.UNLOCK)
	end)
	Events.PlayMinute:Connect(function(player)
		progress(player, "minutes", 1)
	end)

	Net.onAction("ClaimQuest", function(player, index)
		local profile = DataService.get(player)
		if not profile or type(index) ~= "number" then
			return false, "Invalid quest"
		end
		refreshDaily(player)
		local ok, result, tokens = QuestLogic.claim(profile, index)
		if not ok then
			return false, result
		end
		PlayerService.refresh(player)
		local text = "+" .. Format.abbreviate(result) .. " coins"
		if tokens > 0 then
			text ..= string.format(" and %d rebirth token!", tokens)
		end
		Net.fire("Effect", player, "reward", { text = text })
		Analytics.onboarding(player, "FirstQuestClaim")
		Analytics.economy(player, "Source", result, profile.coins, "Gameplay", "Quest")
		return true, result
	end)

	Net.onAction("ClaimStreak", function(player)
		local profile = DataService.get(player)
		if not profile then
			return false, "Loading"
		end
		local ok, result, boost = QuestLogic.claimStreak(profile, os.time())
		if not ok then
			return false, result
		end
		PlayerService.refresh(player)
		local text = "+" .. Format.abbreviate(result) .. " coins"
		if boost > 0 then
			text ..= " and 15 min of 2x Coins!"
		end
		Net.fire("Effect", player, "reward", { text = text })
		Analytics.economy(player, "Source", result, profile.coins, "TimedReward", "Streak")
		return true, result
	end)

	Net.onAction("SkipTutorial", function(player)
		local profile = DataService.get(player)
		if not profile then
			return false, "Loading"
		end
		profile.tutorialStep = T.DONE
		PlayerService.markDirty(player)
		return true, nil
	end)
end

function QuestService:Start()
	-- Roll over quests/streaks for players online across UTC midnight.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				refreshDaily(player)
			end
		end
	end)
end

return QuestService
