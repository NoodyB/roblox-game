--!strict
-- Global leaderboards (OrderedDataStore): lifetime debris cleaned and rebirths.
-- Scores are pushed every few minutes per player and the top 10 are shown on boards in the hub.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local LeaderboardService = {}

local BOARDS = {
	{ key = "Units", title = "🍂 Top Cleaners", store = GameConfig.LeaderboardUnitsStore, field = "lifetimeUnits" },
	{ key = "Rebirths", title = "♻️ Top Rebirths", store = GameConfig.LeaderboardRebirthStore, field = "rebirths" },
}
LeaderboardService.Boards = BOARDS

local stores: { [string]: any } = {}
local nameCache: { [number]: string } = {}
local lastPush: { [Player]: number } = {}

local PUSH_INTERVAL = 180
local REFRESH_INTERVAL = 120

local function scoreFor(profile: any, field: string): number
	if field == "rebirths" then
		return profile.rebirths
	end
	return math.floor(profile.stats[field] or 0)
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function push(player: Player)
	local profile = DataService.get(player)
	if not profile or DataService.isTemporary() then
		return
	end
	lastPush[player] = os.clock()
	for _, board in BOARDS do
		local store = stores[board.key]
		if store then
			local score = scoreFor(profile, board.field)
			if score > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), score)
				end)
			end
		end
	end
end

local function refresh()
	for _, board in BOARDS do
		local store = stores[board.key]
		if store then
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, 10)
			end)
			if ok and pages then
				local entries = {}
				local okPage, page = pcall(function()
					return pages:GetCurrentPage()
				end)
				if okPage and page then
					for rank, entry in page do
						local userId = tonumber(entry.key)
						table.insert(entries, {
							rank = rank,
							name = if userId then nameFor(userId) else "?",
							value = Format.abbreviate(entry.value),
						})
					end
				end
				WorldService.setBoard(board.key, board.title, entries)
			end
		end
	end
end

function LeaderboardService:Init()
	for _, board in BOARDS do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.store)
		end)
		if ok then
			stores[board.key] = store
		end
		WorldService.setBoard(board.key, board.title, {})
	end
	DataService.ProfileReleasing:Connect(function(player)
		push(player)
		lastPush[player] = nil
	end)
end

function LeaderboardService:Start()
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastPush[player] or 0) > PUSH_INTERVAL then
					push(player)
				end
			end
			refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LeaderboardService
