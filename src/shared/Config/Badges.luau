--!strict
-- Roblox badges for milestones. Create them in Creator Dashboard → your experience → Badges,
-- then paste each id here (0 = disabled). Awarding is server-side and idempotent.

export type Badge = { key: string, id: number, name: string, description: string }

local Badges: { Badge } = {
	{ key = "Welcome", id = 0, name = "Welcome to the Squad!", description = "Joined Sweep Squad." },
	{ key = "FirstCritter", id = 0, name = "Critter Friend", description = "Found your first critter." },
	{ key = "Zone4", id = 0, name = "Beach Bound", description = "Unlocked Sunny Shores." },
	{ key = "FirstRebirth", id = 0, name = "Fresh Start", description = "Rebirthed for the first time." },
	{ key = "AllZones", id = 0, name = "To the Moon!", description = "Unlocked Moon Base." },
	{ key = "GoldenCritter", id = 0, name = "Midas Touch", description = "Made a golden critter." },
}

return Badges
