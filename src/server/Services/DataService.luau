--!strict
-- Player persistence with session locking.
--
-- Record format stored under key "Player_<UserId>":
--   { data = <Profile>, lock = { jobId = string, time = number }?, savedAt = number }
--
-- * Load takes the session lock with UpdateAsync. If another live server holds it, we retry
--   (that server is usually finishing its final save); after the retry budget we take over.
-- * Every save verifies we still own the lock. If another server stole it, this server stops
--   saving that player (to avoid overwriting newer data) and kicks them with an explanation.
-- * Autosave refreshes the lock heartbeat; locks older than SessionLockStaleAfter are free.
-- * On leave and on shutdown (BindToClose) the final save releases the lock.
-- * If DataStores are unavailable (e.g. Studio without API access) the game still runs with
--   temporary data, and the player is told progress will not be saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local Signal = require(Shared.Util.Signal)

type Session = {
	key: string,
	jobId: string,
	lockLost: boolean,
	saving: boolean,
	released: boolean,
	lastSave: number,
}

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile) just before the final save

local profiles: { [Player]: DataSchema.Profile } = {}
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local store: any = nil
local temporary = false
local shuttingDown = false

local MAX_ATTEMPTS = 3

-- Overridable in tests so retries/backoff don't actually sleep.
DataService._wait = function(seconds: number)
	task.wait(seconds)
end

local function jobId(): string
	local id = game.JobId
	if id == nil or id == "" then
		return "studio-" .. tostring(os.time())
	end
	return id
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local lastErr
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < MAX_ATTEMPTS then
			DataService._wait(attempt * 2)
		end
	end
	warn(string.format("[DataService] %s failed after %d attempts: %s", label, MAX_ATTEMPTS, tostring(lastErr)))
	return false, nil
end

function DataService.isTemporary(): boolean
	return temporary
end

function DataService.get(player: Player): DataSchema.Profile?
	return profiles[player]
end

-- Waits (up to timeout seconds) for the player's profile to finish loading.
function DataService.waitFor(player: Player, timeout: number?): DataSchema.Profile?
	local deadline = os.clock() + (timeout or 15)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		DataService._wait(0.25)
	end
	return profiles[player]
end

local function loadRecord(player: Player, session: Session): (boolean, any)
	for attempt = 1, GameConfig.SessionLockRetries do
		local blockedBy: string? = nil
		local loaded: any = nil
		local ok = retry("load " .. session.key, function()
			store:UpdateAsync(session.key, function(old: any)
				local now = os.time()
				blockedBy = nil
				if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= session.jobId then
					local age = now - (tonumber(old.lock.time) or 0)
					if age < GameConfig.SessionLockStaleAfter and attempt < GameConfig.SessionLockRetries then
						blockedBy = tostring(old.lock.jobId)
						return nil -- cancel the write; try again shortly
					end
				end
				local record = if type(old) == "table" then old else {}
				loaded = record.data
				record.lock = { jobId = session.jobId, time = now }
				return record
			end)
		end)
		if not ok then
			return false, nil
		end
		if not blockedBy then
			return true, loaded
		end
		if not player.Parent then
			return false, nil
		end
		DataService._wait(GameConfig.SessionLockRetryDelay)
	end
	return false, nil
end

local function onPlayerAdded(player: Player)
	if profiles[player] or loading[player] then
		return
	end
	loading[player] = true
	local session: Session = {
		key = keyFor(player),
		jobId = jobId(),
		lockLost = false,
		saving = false,
		released = false,
		lastSave = os.clock(),
	}

	local raw: any = nil
	local usedTemporary = temporary
	if not temporary then
		local ok, loaded = loadRecord(player, session)
		if not ok then
			if not player.Parent then
				loading[player] = nil
				return
			end
			-- Could not load: never let the player play on a blank profile that would overwrite
			-- their real save. Kick with a clear message instead.
			loading[player] = nil
			player:Kick("We couldn't load your Sweep Squad save right now. Please rejoin in a minute!")
			return
		end
		raw = loaded
	end

	local now = os.time()
	local profile = DataSchema.migrate(raw, now)
	if raw == nil then
		profile.firstJoin = now
	end
	profile.lastJoin = now
	loading[player] = nil

	if not player.Parent then
		-- Player left while we were loading: release the lock we just took.
		if not usedTemporary then
			pcall(function()
				store:UpdateAsync(session.key, function(old: any)
					if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId == session.jobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end

	profiles[player] = profile
	sessions[player] = session
	DataService.ProfileLoaded:Fire(player, profile)
end

-- Saves a player's profile. `release` clears the session lock (final save).
function DataService.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	local session = sessions[player]
	if not profile or not session or session.lockLost or session.released then
		return false
	end
	if temporary then
		return true
	end
	-- serialize concurrent saves for the same player
	while session.saving do
		DataService._wait(0.1)
	end
	if session.lockLost or session.released then
		return false
	end
	session.saving = true
	local lostLock = false
	local ok = retry("save " .. session.key, function()
		store:UpdateAsync(session.key, function(old: any)
			lostLock = false
			if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= session.jobId then
				lostLock = true
				return nil
			end
			return {
				data = profile,
				lock = if release then nil else { jobId = session.jobId, time = os.time() },
				savedAt = os.time(),
			}
		end)
	end)
	session.saving = false
	if lostLock then
		session.lockLost = true
		warn("[DataService] session lock lost for " .. session.key .. "; this server will stop saving it")
		if player.Parent and not shuttingDown then
			player:Kick("Your Sweep Squad save was opened in another server. Please rejoin!")
		end
		return false
	end
	if ok then
		session.lastSave = os.clock()
		if release then
			session.released = true
		end
	end
	return ok
end

-- Immediate save used after purchases. Returns true only if the data is durably stored.
function DataService.saveNow(player: Player): boolean
	return DataService.save(player, false)
end

local function onPlayerRemoving(player: Player)
	loading[player] = nil
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player, profile)
	DataService.save(player, true)
	profiles[player] = nil
	sessions[player] = nil
end

local function onClose()
	shuttingDown = true
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			local profile = profiles[player]
			if profile then
				DataService.ProfileReleasing:Fire(player, profile)
				DataService.save(player, true)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		DataService._wait(0.2)
	end
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok and result then
		store = result
		-- In Studio without "Enable Studio Access to API Services", requests error. Probe once.
		if RunService:IsStudio() then
			local probeOk = pcall(function()
				store:GetAsync("__probe")
			end)
			if not probeOk then
				temporary = true
				warn("[DataService] DataStores unavailable in Studio; running with temporary data")
			end
		end
	else
		temporary = true
		warn("[DataService] DataStores unavailable; running with temporary data: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	game:BindToClose(onClose)
end

function DataService:Start()
	-- Autosave loop: spread saves across the interval to smooth DataStore request usage.
	task.spawn(function()
		while not shuttingDown do
			task.wait(GameConfig.AutosaveInterval)
			local list = {}
			for player in profiles do
				table.insert(list, player)
			end
			local gap = if #list > 0 then math.min(2, GameConfig.AutosaveInterval / (#list + 1)) else 0
			for _, player in list do
				if shuttingDown then
					break
				end
				if profiles[player] then
					task.spawn(DataService.save, player, false)
				end
				task.wait(gap)
			end
		end
	end)
end

-- Test hooks
DataService._onPlayerAdded = onPlayerAdded
DataService._onPlayerRemoving = onPlayerRemoving
DataService._onClose = onClose
function DataService._sessionFor(player: Player): Session?
	return sessions[player]
end

return DataService
