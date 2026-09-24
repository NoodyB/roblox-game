--!strict
-- Seasonal events. Times are unix seconds (UTC). While an event is active:
--  * a share of all critter finds (free drops) are the event's critters
--  * the event zone's debris and atmosphere get the event palette
--  * the hub gets seasonal decorations (applied when a server starts during the event)
-- Event critters are defined in Config/Critters.luau with zone = 0 and `event = <id>`.

export type Event = {
	id: string,
	name: string,
	emoji: string,
	start: number,
	finish: number,
	critterShare: number,
	themeZone: number,
	debris: { Color3 },
	atmosphere: Color3,
	decay: Color3,
	hubDecor: string,
}

local rgb = Color3.fromRGB

local Events: { Event } = {
	{
		id = "halloween2026",
		name = "Haunted Hollow",
		emoji = "🎃",
		start = 1_790_812_800, -- 2026-10-01 00:00 UTC
		finish = 1_793_750_400, -- 2026-11-04 00:00 UTC
		critterShare = 0.2,
		themeZone = 1,
		debris = { rgb(255, 120, 20), rgb(130, 60, 200), rgb(60, 50, 70), rgb(120, 220, 90) },
		atmosphere = rgb(170, 130, 200),
		decay = rgb(255, 120, 60),
		hubDecor = "jackOLantern",
	},
}

return Events
