--!strict
-- The core loop. The server owns every zone's debris grid and does all collection itself from the
-- character positions it already knows, so there is no "I collected X" remote to exploit.
--
-- Every CollectTickRate seconds, for each player:
--   1. sanity-check movement (speed hack / teleport detection) and zone access
--   2. sell if standing on a sell pad
--   3. vacuum cells within the vacuum radius into the bag (value = units * zone value * bonuses)
--   4. roll for critters, credit zone-clear contribution, publish events
-- Changed cells are batched and broadcast as compact buffers every ReplicationRate seconds.
-- When a zone is ~fully clean, contributors get a bonus and the zone refills; every other wave is
-- a Golden Gust (debris worth GoldenWaveMultiplier x).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local DebrisGrid = require(Shared.Logic.DebrisGrid)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local NetCodec = require(Shared.Logic.NetCodec)
local Economy = require(Shared.Logic.Economy)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local PlayerService = require(script.Parent.PlayerService)
local CritterService = require(script.Parent.CritterService)
local WorldService = require(script.Parent.WorldService)
local Events = require(script.Parent.Events)
local Analytics = require(script.Parent.Analytics)

type ZoneState = {
	grid: DebrisGrid.DebrisGrid,
	wave: number,
	golden: boolean,
	clearing: boolean,
	lastGolden: number,
	contributions: { [Player]: number },
}

local DebrisService = {}

local zones: { [number]: ZoneState } = {}
local dirty: { [number]: { [number]: boolean } } = {}
local pads: { [number]: { { x: number, z: number } } } = {}

local function markDirty(zoneId: number, indices: { number })
	local set = dirty[zoneId]
	if not set then
		set = {}
		dirty[zoneId] = set
	end
	for _, index in indices do
		set[index] = true
	end
end

function DebrisService.getZone(zoneId: number): ZoneState?
	return zones[zoneId]
end

function DebrisService.snapshotAll(): { [string]: any }
	local result = {}
	for zoneId, state in zones do
		result[tostring(zoneId)] = { wave = state.wave, golden = state.golden, cells = state.grid:snapshot() }
	end
	return result
end

-- Sells the player's bag. Returns coins earned.
function DebrisService.sell(player: Player): number
	local profile = DataService.get(player)
	local stats = PlayerService.getStats(player)
	if not profile or not stats or profile.bagUnits <= 0 then
		return 0
	end
	local units = profile.bagUnits
	local coins = Economy.sellValue(profile.bagValue, stats.coinMultiplier)
	profile.coins += coins
	profile.stats.lifetimeCoins += coins
	profile.stats.sells += 1
	profile.bagUnits = 0
	profile.bagValue = 0
	PlayerService.touch(player)
	Net.fire("Effect", player, "sell", { coins = coins, units = units })
	Events.Sold:Fire(player, coins, units)
	if profile.stats.sells == 1 then
		Analytics.onboarding(player, "FirstSell")
	end
	Analytics.economy(player, "Source", coins, profile.coins, "Gameplay", "Sell")
	return coins
end

local function squadBonus(player: Player, position: Vector3, zoneId: number): number
	local count = 0
	local radius2 = GameConfig.SquadRadius * GameConfig.SquadRadius
	for other, session in PlayerService.allSessions() do
		if other ~= player and session.zone == zoneId and session.lastPos then
			local d = session.lastPos - position
			if d.X * d.X + d.Z * d.Z <= radius2 then
				count += 1
			end
		end
	end
	return math.min(GameConfig.SquadBonusMax, count * GameConfig.SquadBonusPerPlayer)
end

local function startClear(zoneId: number)
	local state = zones[zoneId]
	if not state or state.clearing then
		return
	end
	state.clearing = true
	local zone = Zones[zoneId]
	local contributors = state.contributions
	state.contributions = {}

	for player, value in contributors do
		local profile = DataService.get(player)
		local stats = PlayerService.getStats(player)
		if profile and stats and player.Parent then
			local bonus = math.floor(value * GameConfig.ZoneClearBonusFactor * stats.coinMultiplier)
			profile.coins += bonus
			profile.stats.lifetimeCoins += bonus
			profile.stats.zoneClears += 1
			PlayerService.touch(player)
			Net.fire("Effect", player, "zoneClear", { zoneId = zoneId, bonus = bonus })
			Events.ZoneCleared:Fire(player, zoneId)
			Analytics.economy(player, "Source", bonus, profile.coins, "Gameplay", "ZoneClear")
		end
	end

	-- alternate normal/golden, but never more often than GoldenCooldown (crowded servers clear fast)
	local nextGolden = not state.golden and os.clock() - state.lastGolden >= GameConfig.GoldenCooldown
	Net.fireAll(
		"Notify",
		"success",
		string.format(
			"%s %s is sparkling clean! %s",
			zone.emoji,
			zone.name,
			if nextGolden then "A GOLDEN GUST is blowing in!" else "Fresh debris incoming!"
		)
	)

	task.delay(GameConfig.GustDelay, function()
		state.wave += 1
		state.golden = nextGolden
		if nextGolden then
			state.lastGolden = os.clock()
		end
		state.grid:fill()
		state.clearing = false
		dirty[zoneId] = nil
		Net.fireAll("ZoneWave", zoneId, state.wave, state.golden, state.grid:snapshot())
	end)
end
DebrisService._startClear = startClear

local function standingOnPad(zoneId: number, position: Vector3): boolean
	local r2 = GameConfig.SellPadRadius * GameConfig.SellPadRadius
	for _, pad in pads[zoneId] do
		local dx, dz = position.X - pad.x, position.Z - pad.z
		if dx * dx + dz * dz <= r2 then
			return true
		end
	end
	return false
end

-- One collection step for one player. Exposed for tests.
function DebrisService.step(player: Player, position: Vector3, now: number)
	local profile = DataService.get(player)
	local session = PlayerService.getSession(player)
	if not profile or not session then
		return
	end
	local stats = session.stats

	-- 1. movement sanity (horizontal speed only; falling is fine)
	local lastPos = session.lastPos
	local elapsed = now - session.lastPosTime
	session.lastPos = position
	session.lastPosTime = now
	if lastPos and now > session.graceUntil and elapsed > 0 then
		local d = position - lastPos
		local horizontal = math.sqrt(d.X * d.X + d.Z * d.Z)
		local allowed = stats.walkSpeed * elapsed * GameConfig.SpeedTolerance + 6
		if horizontal > allowed then
			session.flags += 1
			if session.flags >= GameConfig.MaxFlagsBeforeReset then
				session.flags = 0
				WorldService.teleport(player, math.max(1, math.min(profile.maxZone, session.zone or 1)))
				PlayerService.setGrace(player)
			end
			return
		end
	end
	if session.flags > 0 and math.random() < 0.02 then
		session.flags -= 1 -- slowly forgive
	end

	local zoneId = ZoneLayout.zoneAt(position.X, position.Z)
	if session.zone ~= zoneId then
		session.zone = zoneId
		player:SetAttribute("Zone", zoneId or -1)
	end
	if not zoneId or zoneId < 1 then
		return
	end

	-- 2. zone access (gates are client-collidable; this is the authoritative check)
	if zoneId > profile.maxZone then
		WorldService.teleport(player, profile.maxZone)
		PlayerService.setGrace(player)
		Net.notify(player, "error", "Unlock " .. Zones[zoneId].name .. " at its gate first!")
		return
	end
	if position.Y - GameConfig.GroundY > GameConfig.MaxCollectHeight then
		return
	end

	-- 3. selling
	if profile.bagUnits > 0 and standingOnPad(zoneId, position) then
		DebrisService.sell(player)
	end

	-- 4. collecting
	local state = zones[zoneId]
	if not state then
		return
	end
	local space = stats.capacity - profile.bagUnits
	if space <= 0 then
		if PassService.owns(player, "AutoSell") then
			DebrisService.sell(player)
			space = stats.capacity
		else
			if now - session.lastBagFullNotice > 4 then
				session.lastBagFullNotice = now
				Net.fire("Effect", player, "bagFull", {})
			end
			return
		end
	end

	local changed = {}
	local units = state.grid:collect(position.X, position.Z, stats.radius, stats.power, space, changed)
	if units <= 0 then
		return
	end
	markDirty(zoneId, changed)

	local zone = Zones[zoneId]
	local bonus = squadBonus(player, position, zoneId)
	local value = units * zone.unitValue * (if state.golden then GameConfig.GoldenWaveMultiplier else 1) * (1 + bonus)
	local firstCollect = profile.stats.lifetimeUnits == 0
	profile.bagUnits += units
	profile.bagValue += value
	profile.stats.lifetimeUnits += units
	state.contributions[player] = (state.contributions[player] or 0) + value
	PlayerService.touch(player)

	Events.Collected:Fire(player, units, zoneId, state.golden)
	CritterService.onCollectTick(player, zoneId)
	if firstCollect then
		Analytics.onboarding(player, "FirstCollect")
	end

	if profile.bagUnits >= stats.capacity and PassService.owns(player, "AutoSell") then
		DebrisService.sell(player)
	end

	if not state.clearing and state.grid:cleanFraction() >= GameConfig.ZoneClearThreshold then
		startClear(zoneId)
	end
end

local function collectTick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local ok, err = pcall(DebrisService.step, player, root.Position, now)
			if not ok then
				warn("[DebrisService] step failed for " .. player.Name .. ": " .. tostring(err))
			end
		end
	end
end

local function flush()
	if next(dirty) == nil then
		return
	end
	local payload = NetCodec.encodeDirty(dirty, function(zoneId, index)
		return zones[zoneId].grid:get(index)
	end)
	table.clear(dirty)
	if payload then
		Net.fireAll("DebrisDelta", payload)
	end
end
DebrisService._flush = flush

function DebrisService:Init()
	for zoneId = 1, #Zones do
		local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
		local grid = DebrisGrid.new({
			cols = cols,
			rows = rows,
			cellSize = GameConfig.CellSize,
			originX = originX,
			originZ = originZ,
			cellMax = GameConfig.CellMax,
			mask = ZoneLayout.mask(zoneId),
			reachPadding = GameConfig.CellReachPadding,
		})
		grid:fill()
		zones[zoneId] = { grid = grid, wave = 1, golden = false, clearing = false, lastGolden = -math.huge, contributions = {} }
		pads[zoneId] = ZoneLayout.sellPads(zoneId)
	end

	-- Handshake: the client calls Hello once its listeners are connected.
	Net.onAction("Hello", function(player)
		local state = PlayerService.buildState(player)
		if not state then
			return false, "loading"
		end
		Net.setReady(player)
		return true, { state = state, debris = DebrisService.snapshotAll() }
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, state in zones do
			state.contributions[player] = nil
		end
	end)
end

function DebrisService:Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.CollectTickRate)
			collectTick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.ReplicationRate)
			flush()
		end
	end)
end


return DebrisService
