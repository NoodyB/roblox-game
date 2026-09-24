--!strict
-- Names of every remote. The server creates them under ReplicatedStorage.Remotes at startup.
--
-- Server -> client events:
--   State(stateTable)                full client view of the player's profile + derived stats
--   DebrisDelta(buffer)              batched debris cell changes (see NetCodec)
--   ZoneWave(zoneId, wave, golden, buffer)   a zone was refilled
--   Notify(kind, text)               toast message ("info" | "success" | "error" | "reward")
--   Effect(kind, payload)            one-shot feedback (sell, critter, zoneClear, purchase, storm, levelUp)
--
-- Client -> server:
--   Action(actionName, payload) -> { ok: boolean, err: string?, data: any? }   (RemoteFunction)

local Remotes = {
	FolderName = "Remotes",
	Events = { "State", "DebrisDelta", "ZoneWave", "Notify", "Effect" },
	ActionFunction = "Action",

	-- Every action the server accepts. Anything else is rejected before reaching game code.
	Actions = {
		"Hello",
		"BuyUpgrade",
		"UnlockZone",
		"Teleport",
		"EquipCritters",
		"AutoEquip",
		"MakeGolden",
		"Rebirth",
		"BuyPerk",
		"ClaimQuest",
		"ClaimStreak",
		"SaveSettings",
		"SkipTutorial",
		"RedeemCode",
	},
}

return Remotes
