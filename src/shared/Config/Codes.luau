--!strict
-- Redeemable promo codes (for social posts / creator videos). Codes are case-insensitive.
-- Each player can redeem each code once. `expires` is a unix timestamp (nil = never).
-- Rewards: "coins" (in full bags of the best zone), "boost" (seconds of a boost), "critter" (one copy).

export type Code = {
	reward: string,
	bags: number?,
	boost: string?,
	seconds: number?,
	critter: string?,
	expires: number?,
}

local Codes: { [string]: Code } = {
	SWEEPSQUAD = { reward = "coins", bags = 5 },
	LAUNCH = { reward = "boost", boost = "coins2x", seconds = 15 * 60 },
	SQUIRREL = { reward = "critter", critter = "squirrel" },
}

return Codes
