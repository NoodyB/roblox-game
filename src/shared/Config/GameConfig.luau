--!strict
-- Global tuning constants for Sweep Squad.
-- Everything balance-related lives in src/shared/Config so it can be tuned without touching logic.

local GameConfig = {
	GameName = "Sweep Squad",
	Version = "0.1.0",

	-- Persistence
	DataStoreName = "SweepSquad_PlayerData_v1",
	LeaderboardUnitsStore = "SweepSquad_LB_Units_v1",
	LeaderboardRebirthStore = "SweepSquad_LB_Rebirths_v1",
	AutosaveInterval = 90, -- seconds
	SessionLockStaleAfter = 240, -- seconds without a heartbeat before another server may take the lock
	SessionLockRetries = 6,
	SessionLockRetryDelay = 4,
	MaxReceiptHistory = 100,

	-- World layout (studs)
	HubSize = 150,
	ZoneSize = 150,
	ZoneSpacing = 200, -- zone k is centered at X = k * ZoneSpacing
	DebrisAreaSize = 132, -- square area inside each zone that holds debris
	CellSize = 6,
	CellMax = 6, -- debris units in a full cell
	GroundY = 0,
	GateWidth = 18,
	GateHeight = 16,
	WallHeight = 40,

	-- Collection loop
	CollectTickRate = 0.2, -- seconds between server collection ticks
	ReplicationRate = 0.1, -- seconds between debris delta flushes
	MaxCollectHeight = 14, -- root must be within this many studs above ground to collect
	CellReachPadding = 2, -- extra reach so cells at the edge of the radius still count

	-- Zone waves
	ZoneClearThreshold = 0.97, -- fraction cleaned that counts as a full clear
	GustDelay = 4, -- seconds between a zone clear and the refill
	GoldenWaveMultiplier = 3,
	GoldenCooldown = 180, -- min seconds between golden waves in a zone (busy servers clear zones fast)
	ZoneClearBonusFactor = 0.5, -- contributors get this fraction of their contributed value as bonus

	-- Social
	GroupId = 0, -- your Roblox group id; members get GroupBonus coins (0 = disabled)
	GroupBonus = 0.1,
	SquadRadius = 40,
	SquadBonusPerPlayer = 0.1,
	SquadBonusMax = 0.3,

	-- Selling
	SellPadRadius = 10,

	-- Critters
	BaseEquipSlots = 3,
	PassEquipSlots = 2,
	GoldenCost = 5, -- duplicates consumed to make one golden critter
	GoldenBonusMultiplier = 2.5,
	CritterBaseFindChance = 1 / 450, -- per collection tick that collected something
	CritterPityTicks = 900, -- guaranteed find after this many collecting ticks without one
	FirstCritterGuaranteeTicks = 120, -- new players get their first critter quickly

	-- Anti-cheat
	SpeedTolerance = 1.6, -- multiplier on max walk speed before a movement sample is rejected
	TeleportGraceSeconds = 2,
	MaxFlagsBeforeReset = 12,

	-- Remote rate limits (requests per second, burst)
	RemoteRate = 8,
	RemoteBurst = 16,

	-- Daily systems
	DailyQuestCount = 3,
	StreakLength = 7,
}

return GameConfig
