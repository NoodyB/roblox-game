--!strict
-- Monetization catalogue.
--
-- IDs are the real game passes / developer products created by the owner in the Creator Dashboard
-- (they only work inside that experience). A 0 id disables that purchase button in-game.
-- See docs/Games/Sweep Squad/Monetization.md for the setup checklist.
--
-- Design rules (see Monetization.md):
--  * No randomized items are ever sold for Robux (no paid gacha).
--  * Everything purchasable is also described exactly, with its price, before the prompt opens.
--  * Free players can reach all content; purchases only save time or add cosmetics/social fun.

export type GamePass = {
	key: string,
	id: number,
	name: string,
	emoji: string,
	description: string,
	priceHint: number,
}

export type DevProduct = {
	key: string,
	id: number,
	name: string,
	emoji: string,
	description: string,
	priceHint: number,
	kind: string, -- "coins" | "boost" | "storm"
	amount: number, -- coin pack: number of full bags; boost/storm: seconds
	boost: string?,
}

local Products = {}

Products.GamePasses = {
	{ key = "VIP", id = 1995278298, name = "VIP", emoji = "👑", description = "+20% coins forever, a golden VIP chat tag and +1 critter slot.", priceHint = 199 },
	{ key = "DoubleCoins", id = 1995098303, name = "2x Coins", emoji = "💰", description = "Permanently doubles all coins from selling.", priceHint = 399 },
	{ key = "AutoSell", id = 1995668303, name = "Auto Sell", emoji = "♻️", description = "Your bag sells itself the moment it's full, anywhere.", priceHint = 149 },
	{ key = "CritterSlots", id = 1994858313, name = "+2 Critter Slots", emoji = "🐾", description = "Equip two more critters at once.", priceHint = 249 },
} :: { GamePass }

Products.DevProducts = {
	{ key = "CoinsSmall", id = 3714449356, name = "Coin Pouch", emoji = "🪙", description = "Coins worth 3 full bags of your best zone's debris.", priceHint = 49, kind = "coins", amount = 3 },
	{ key = "CoinsMedium", id = 3714449542, name = "Coin Crate", emoji = "📦", description = "Coins worth 12 full bags of your best zone's debris.", priceHint = 149, kind = "coins", amount = 12 },
	{ key = "CoinsLarge", id = 3714449567, name = "Coin Vault", emoji = "🏦", description = "Coins worth 40 full bags of your best zone's debris.", priceHint = 399, kind = "coins", amount = 40 },
	{ key = "BoostCoins", id = 3714449617, name = "2x Coins (30 min)", emoji = "⚡", description = "Double coins for 30 minutes of play time. Stacks.", priceHint = 59, kind = "boost", amount = 30 * 60, boost = "coins2x" },
	{ key = "BoostCollect", id = 3714449653, name = "Super Suction (30 min)", emoji = "🌪️", description = "Double vacuum power and +3 reach for 30 minutes of play time. Stacks.", priceHint = 59, kind = "boost", amount = 30 * 60, boost = "collect2x" },
	{ key = "GoldenStorm", id = 3714449675, name = "Golden Storm", emoji = "🌟", description = "Everyone in the server earns 2x coins for 5 minutes. Your name goes up in lights!", priceHint = 99, kind = "storm", amount = 5 * 60 },
} :: { DevProduct }

Products.PassByKey = {} :: { [string]: GamePass }
Products.PassById = {} :: { [number]: GamePass }
for _, pass in Products.GamePasses do
	Products.PassByKey[pass.key] = pass
	if pass.id ~= 0 then
		Products.PassById[pass.id] = pass
	end
end

Products.ProductByKey = {} :: { [string]: DevProduct }
Products.ProductById = {} :: { [number]: DevProduct }
for _, product in Products.DevProducts do
	Products.ProductByKey[product.key] = product
	if product.id ~= 0 then
		Products.ProductById[product.id] = product
	end
end

-- VIP chat tag / multiplier values
Products.VipCoinMultiplier = 1.2
Products.VipExtraSlots = 1
Products.DoubleCoinsMultiplier = 2
Products.GoldenStormMultiplier = 2

return Products
