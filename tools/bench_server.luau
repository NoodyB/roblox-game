--!nocheck
-- Server performance benchmark: runs the real DebrisService collection step + replication encode
-- for N simulated players walking around a zone, and reports time per server tick.
--   lune run tools/bench_server.luau [players=12] [ticks=500]
-- Lune runs the same Luau VM as Roblox (without native codegen), so this is a reasonable proxy for
-- server script cost. It excludes engine work (physics, replication transport).

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local Harness = require("../tests/harness")
local Mocks = require("../tests/mocks")

local PLAYERS = tonumber(process.args[1]) or 12
local TICKS = tonumber(process.args[2]) or 500

Harness.reset()
local mocks = Mocks.install(Harness)
Harness.silenceWarnings = true
local R = function(path)
	return Harness.requirePath(path)
end
local GameConfig = R("ReplicatedStorage.Shared.Config.GameConfig")
local ZoneLayout = R("ReplicatedStorage.Shared.Logic.ZoneLayout")
local Net = R("ServerScriptService.Server.Services.Net")
local sentBytes = 0
local sentMessages = 0
Net.fire = function() end
Net.notify = function() end
Net.fireAll = function(name, payload)
	if name == "DebrisDelta" and payload then
		sentBytes += buffer.len(payload)
		sentMessages += 1
	end
end
local DataService = R("ServerScriptService.Server.Services.DataService")
DataService._wait = function() end
local PassService = R("ServerScriptService.Server.Services.PassService")
local PlayerService = R("ServerScriptService.Server.Services.PlayerService")
local CritterService = R("ServerScriptService.Server.Services.CritterService")
local DebrisService = R("ServerScriptService.Server.Services.DebrisService")
local QuestService = R("ServerScriptService.Server.Services.QuestService")
DataService:Init()
PassService:Init()
PlayerService:Init()
CritterService:Init()
DebrisService:Init()
QuestService:Init()

-- players with mid-game gear, walking in circles around zone 3
local players = {}
local zoneId = 3
local cx = ZoneLayout.center(zoneId)
for i = 1, PLAYERS do
	local player = mocks.Players.add(1000 + i)
	DataService._onPlayerAdded(player)
	local profile = DataService.get(player)
	profile.maxZone = 3
	profile.vacuumTier = 5 -- typical gear for zone 3
	profile.bagTier = 5
	profile.bootsTier = 3
	PlayerService.refresh(player)
	PlayerService.getSession(player).graceUntil = math.huge -- no anti-cheat noise from scripted paths
	-- start spread out; each player bounces around the debris field at walking speed
	local heading = i * 2.39996
	table.insert(players, {
		player = player,
		x = cx + math.cos(heading) * 40,
		z = math.sin(heading) * 40,
		vx = math.cos(heading * 1.7) * 26,
		vz = math.sin(heading * 1.7) * 26,
	})
end

local stepTimes = {}
local flushTimes = {}
local dt = GameConfig.CollectTickRate
local clock = 0
for tick = 1, TICKS do
	clock += dt
	local started = os.clock()
	for _, entry in players do
		entry.x += entry.vx * dt
		entry.z += entry.vz * dt
		if math.abs(entry.x - cx) > 62 then
			entry.vx = -entry.vx
			entry.x = math.clamp(entry.x, cx - 62, cx + 62)
		end
		if math.abs(entry.z) > 62 then
			entry.vz = -entry.vz
			entry.z = math.clamp(entry.z, -62, 62)
		end
		DebrisService.step(entry.player, Vector3.new(entry.x, 3, entry.z), clock)
	end
	table.insert(stepTimes, os.clock() - started)
	-- refill cleared zones immediately (the real game waits GustDelay seconds of wall time)
	local zone = DebrisService.getZone(zoneId)
	if zone.clearing then
		zone.grid:fill()
		zone.clearing = false
		zone.wave += 1
	end
	local flushStart = os.clock()
	DebrisService._flush()
	DebrisService._flush()
	table.insert(flushTimes, os.clock() - flushStart)
end

local function stats(list)
	table.sort(list)
	local sum = 0
	for _, v in list do
		sum += v
	end
	return sum / #list * 1000, list[math.floor(#list * 0.5)] * 1000, list[math.floor(#list * 0.99)] * 1000
end
local avg, median, p99 = stats(stepTimes)
local favg, _, fp99 = stats(flushTimes)
print(string.format("players=%d ticks=%d (%.0fs of play)", PLAYERS, TICKS, TICKS * dt))
print(string.format("collection step per server tick: avg %.3f ms, median %.3f ms, p99 %.3f ms", avg, median, p99))
print(string.format("replication encode per tick:     avg %.3f ms, p99 %.3f ms", favg, fp99))
local seconds = TICKS * dt
print(string.format("debris replication: %.0f bytes/s to every client (%d messages)", sentBytes / seconds, sentMessages))
print(string.format("share of a 0.2s tick budget used: %.2f%%", avg / (dt * 1000) * 100))
local zone = DebrisService.getZone(zoneId)
print(string.format("zone waves completed during the run: %d", zone.wave - 1))
