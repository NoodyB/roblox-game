--!strict
-- Per-player runtime state: derived stats, replicated attributes, leaderstats, the client state
-- sync, character setup (walk speed + gear), boost timers, play time and the server-wide storm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local GearModels = require(Shared.World.GearModels)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local Events = require(script.Parent.Events)

export type Session = {
	stats: Stats.Result,
	dirty: boolean,
	zone: number?,
	lastPos: Vector3?,
	lastPosTime: number,
	graceUntil: number,
	flags: number,
	lastBagFullNotice: number,
	minuteCounter: number,
	gearKey: string,
}

local PlayerService = {}

local sessions: { [Player]: Session } = {}
local storm = { endsAt = 0, by = "" }

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

function PlayerService.stormActive(): boolean
	return serverNow() < storm.endsAt
end

function PlayerService.getSession(player: Player): Session?
	return sessions[player]
end

function PlayerService.getStats(player: Player): Stats.Result?
	local session = sessions[player]
	return session and session.stats
end

function PlayerService.allSessions(): { [Player]: Session }
	return sessions
end

local function computeStats(player: Player, profile: DataSchema.Profile): Stats.Result
	return Stats.compute(profile, { passes = PassService.passes(player), storm = PlayerService.stormActive() })
end

local function setAttributes(player: Player, profile: DataSchema.Profile, stats: Stats.Result)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("BagUnits", profile.bagUnits)
	player:SetAttribute("BagCapacity", stats.capacity)
	player:SetAttribute("VacuumTier", profile.vacuumTier)
	player:SetAttribute("BagTier", profile.bagTier)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("Equipped", table.concat(profile.equipped, ",", 1, math.min(#profile.equipped, stats.equipSlots)))
	player:SetAttribute("VIP", PassService.owns(player, "VIP"))
	player:SetAttribute("Radius", stats.radius)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins") :: StringValue?
		if coins then
			coins.Value = Format.abbreviate(profile.coins)
		end
		local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?
		if rebirths then
			rebirths.Value = profile.rebirths
		end
	end
end

local function applyCharacter(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	local character = player.Character
	if not session or not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = session.stats.walkSpeed
	end
	local key = profile.vacuumTier .. ":" .. profile.bagTier
	if session.gearKey ~= key or not character:FindFirstChild("SweepGear") then
		session.gearKey = key
		GearModels.equip(character, profile.vacuumTier, profile.bagTier)
	end
end

-- Recompute stats after any profile change. Cheap; call freely.
function PlayerService.refresh(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if not session or not profile then
		return
	end
	session.stats = computeStats(player, profile)
	setAttributes(player, profile, session.stats)
	applyCharacter(player)
	session.dirty = true
end

-- Lightweight update for the hot path (collect/sell): attributes only + mark state dirty.
function PlayerService.touch(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if not session or not profile then
		return
	end
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("BagUnits", profile.bagUnits)
	session.dirty = true
end

function PlayerService.markDirty(player: Player)
	local session = sessions[player]
	if session then
		session.dirty = true
	end
end

function PlayerService.setGrace(player: Player, seconds: number?)
	local session = sessions[player]
	if session then
		session.graceUntil = os.clock() + (seconds or GameConfig.TeleportGraceSeconds)
		session.lastPos = nil
	end
end

function PlayerService.buildState(player: Player): { [string]: any }?
	local session = sessions[player]
	local profile = DataService.get(player)
	if not session or not profile then
		return nil
	end
	local view = DataSchema.clientView(profile)
	view.derived = session.stats
	view.passes = PassService.passes(player)
	view.temporaryData = DataService.isTemporary()
	view.storm = { endsAt = storm.endsAt, by = storm.by }
	return view
end

local function sendState(player: Player)
	local session = sessions[player]
	if not session or not Net.isReady(player) then
		return
	end
	local state = PlayerService.buildState(player)
	if state then
		session.dirty = false
		Net.fire("State", player, state)
	end
end

function PlayerService.startStorm(seconds: number, byName: string)
	local now = serverNow()
	storm.endsAt = math.max(storm.endsAt, now) + seconds
	storm.by = byName
	Workspace:SetAttribute("StormEndsAt", storm.endsAt)
	Workspace:SetAttribute("StormBy", byName)
	for player in sessions do
		PlayerService.refresh(player)
	end
	Net.fireAll("Effect", "storm", { by = byName, endsAt = storm.endsAt })
end

local function onProfileLoaded(player: Player, profile: DataSchema.Profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	sessions[player] = {
		stats = computeStats(player, profile),
		dirty = true,
		zone = nil,
		lastPos = nil,
		lastPosTime = os.clock(),
		graceUntil = os.clock() + 5,
		flags = 0,
		lastBagFullNotice = 0,
		minuteCounter = 0,
		gearKey = "",
	}
	PlayerService.refresh(player)

	player.CharacterAdded:Connect(function(character)
		local session = sessions[player]
		if session then
			session.gearKey = ""
			PlayerService.setGrace(player, 3)
		end
		character:WaitForChild("HumanoidRootPart", 10)
		applyCharacter(player)
	end)
	if player.Character then
		applyCharacter(player)
	end
end

local function onSecond()
	local stormWasActive = storm.endsAt > 0 and serverNow() - 1 < storm.endsAt
	for player, session in sessions do
		local profile = DataService.get(player)
		if profile then
			local boostEnded = false
			for key, remaining in profile.boosts do
				if remaining > 0 then
					profile.boosts[key] = math.max(0, remaining - 1)
					if profile.boosts[key] == 0 then
						boostEnded = true
					end
				end
			end
			profile.stats.playSeconds += 1
			session.minuteCounter += 1
			if session.minuteCounter >= 60 then
				session.minuteCounter = 0
				Events.PlayMinute:Fire(player)
			end
			if boostEnded then
				Net.notify(player, "info", "A boost just ran out.")
				PlayerService.refresh(player)
			end
		end
	end
	if stormWasActive and not PlayerService.stormActive() then
		for player in sessions do
			PlayerService.refresh(player)
		end
	end
end

function PlayerService:Init()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	PassService.Changed:Connect(function(player)
		PlayerService.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)

	Net.onAction("SaveSettings", function(player, payload)
		local profile = DataService.get(player)
		if not profile or type(payload) ~= "table" then
			return false, "Invalid settings"
		end
		for key, value in payload do
			if type(key) == "string" and profile.settings[key] ~= nil and type(value) == "boolean" then
				profile.settings[key] = value
			end
		end
		PlayerService.markDirty(player)
		return true, nil
	end)
end

function PlayerService:Start()
	-- state sync (debounced) + 1 Hz timers
	task.spawn(function()
		local accumulator = 0
		while true do
			local dt = task.wait(0.25)
			for player, session in sessions do
				if session.dirty then
					sendState(player)
				end
			end
			accumulator += dt
			while accumulator >= 1 do
				accumulator -= 1
				onSecond()
			end
		end
	end)
end

PlayerService._onProfileLoaded = onProfileLoaded
PlayerService._onSecond = onSecond

return PlayerService
