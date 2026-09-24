--!strict
-- Seasonal events. Times are unix seconds (UTC). While an event is active:
--  * a share of all critter finds (free drops) are the event's critters
--  * the event zone's debris and atmosphere get the event palette
--  * the hub gets seasonal decorations (applied when a server starts during the event)
--  * optional weather (e.g. snowfall) in the event zone
-- Event critters are defined in Config/Critters.luau with zone = 0 and `event = <id>`.

export type Event = {
	id: string,
	name: string,
	emoji: string,
	tagline: string, -- shown in the "event is live" toast, e.g. "Spooky critters"
	start: number,
	finish: number,
	critterShare: number,
	themeZone: number,
	debris: { Color3 },
	atmosphere: Color3,
	decay: Color3,
	hubDecor: string,
	weather: string?, -- overrides the theme zone's weather while active (e.g. "snow")
}

local rgb = Color3.fromRGB

local Events: { Event } = {
	{
		id = "halloween2026",
		name = "Haunted Hollow",
		emoji = "🎃",
		tagline = "Spooky critters",
		start = 1_790_812_800, -- 2026-10-01 00:00 UTC
		finish = 1_793_750_400, -- 2026-11-04 00:00 UTC
		critterShare = 0.2,
		themeZone = 1,
		debris = { rgb(255, 120, 20), rgb(130, 60, 200), rgb(60, 50, 70), rgb(120, 220, 90) },
		atmosphere = rgb(170, 130, 200),
		decay = rgb(255, 120, 60),
		hubDecor = "jackOLantern",
	},
	{
		id = "winter2026",
		name = "Snow Day",
		emoji = "❄️",
		tagline = "Snowfall and cozy winter critters",
		start = 1_797_033_600, -- 2026-12-12 00:00 UTC
		finish = 1_799_193_600, -- 2027-01-06 00:00 UTC
		critterShare = 0.2,
		themeZone = 1,
		debris = { rgb(245, 250, 255), rgb(170, 215, 255), rgb(220, 60, 70), rgb(60, 170, 90) },
		atmosphere = rgb(210, 225, 255),
		decay = rgb(170, 200, 255),
		hubDecor = "snowman",
		weather = "snow",
	},
}

return Events
