--!strict
-- Server-internal gameplay events. Services publish here instead of requiring each other,
-- which keeps the dependency graph acyclic (e.g. QuestService listens, DebrisService publishes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

return {
	Collected = Signal.new(), -- (player, units, zoneId, golden)
	Sold = Signal.new(), -- (player, coins, units)
	CritterFound = Signal.new(), -- (player, critterId)
	ZoneCleared = Signal.new(), -- (player, zoneId) fired once per contributor
	Upgraded = Signal.new(), -- (player, track, newTier)
	ZoneUnlocked = Signal.new(), -- (player, zoneId)
	Rebirthed = Signal.new(), -- (player, rebirthCount)
	PlayMinute = Signal.new(), -- (player) once per minute of play
	Purchased = Signal.new(), -- (player, productKey)
}
