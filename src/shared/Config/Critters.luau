--!strict
-- Critters are companions found (for free) while cleaning. They are never sold for Robux.
-- Drop odds per zone are shown in-game in the Critter Book.

export type BonusType = "coins" | "radius" | "capacity" | "speed" | "find"

export type Critter = {
	id: string,
	name: string,
	zone: number,
	rarity: string,
	weight: number, -- relative drop weight inside its zone
	bonus: BonusType,
	value: number,
	archetype: string, -- visual archetype used by CritterModels
	body: Color3,
	accent: Color3,
	ears: string?,
	tail: string?,
	extra: string?,
	event: string?, -- seasonal event id (zone = 0): only drops while that event is active
}

local rgb = Color3.fromRGB

local Critters = {}

Critters.Rarities = {
	Common = { order = 1, color = rgb(160, 200, 160) },
	Rare = { order = 2, color = rgb(90, 170, 255) },
	Epic = { order = 3, color = rgb(190, 110, 255) },
	Legendary = { order = 4, color = rgb(255, 180, 40) },
	Mythic = { order = 5, color = rgb(255, 80, 140) },
}

Critters.BonusLabels = {
	coins = "Coins",
	radius = "Reach",
	capacity = "Bag Size",
	speed = "Walk Speed",
	find = "Critter Luck",
}

Critters.List = {
	-- Zone 1: Backyard Lane
	{ id = "squirrel", name = "Acorn Squirrel", zone = 1, rarity = "Common", weight = 70, bonus = "coins", value = 0.08, archetype = "quad", body = rgb(196, 120, 64), accent = rgb(250, 220, 180), ears = "round", tail = "bushy" },
	{ id = "hedgehog", name = "Leafy Hedgehog", zone = 1, rarity = "Rare", weight = 25, bonus = "radius", value = 0.5, archetype = "blob", body = rgb(140, 100, 70), accent = rgb(240, 200, 160), extra = "spikes" },
	{ id = "fox", name = "Maple Fox", zone = 1, rarity = "Epic", weight = 5, bonus = "coins", value = 0.2, archetype = "quad", body = rgb(240, 110, 40), accent = rgb(255, 245, 235), ears = "pointy", tail = "bushy" },
	-- Zone 2: Pumpkin Patch Park
	{ id = "crow", name = "Patch Crow", zone = 2, rarity = "Common", weight = 70, bonus = "capacity", value = 0.1, archetype = "bird", body = rgb(50, 50, 60), accent = rgb(255, 190, 60) },
	{ id = "toad", name = "Gourd Toad", zone = 2, rarity = "Rare", weight = 25, bonus = "find", value = 0.1, archetype = "blob", body = rgb(240, 140, 40), accent = rgb(110, 160, 60), extra = "stem" },
	{ id = "lanterncat", name = "Lantern Cat", zone = 2, rarity = "Epic", weight = 5, bonus = "coins", value = 0.25, archetype = "quad", body = rgb(60, 50, 70), accent = rgb(255, 170, 60), ears = "pointy", tail = "thin", extra = "glow" },
	-- Zone 3: Pinecone Forest
	{ id = "owl", name = "Pine Owl", zone = 3, rarity = "Common", weight = 70, bonus = "radius", value = 0.5, archetype = "bird", body = rgb(150, 110, 70), accent = rgb(250, 230, 190), ears = "tufts" },
	{ id = "bunny", name = "Moss Bunny", zone = 3, rarity = "Rare", weight = 25, bonus = "speed", value = 1, archetype = "quad", body = rgb(200, 220, 180), accent = rgb(110, 170, 90), ears = "long", tail = "puff" },
	{ id = "bear", name = "Timber Bear", zone = 3, rarity = "Epic", weight = 5, bonus = "capacity", value = 0.3, archetype = "quad", body = rgb(120, 80, 50), accent = rgb(200, 160, 120), ears = "round", tail = "puff" },
	-- Zone 4: Sunny Shores
	{ id = "crab", name = "Beach Crab", zone = 4, rarity = "Common", weight = 70, bonus = "coins", value = 0.12, archetype = "sea", body = rgb(240, 90, 70), accent = rgb(255, 220, 200), extra = "claws" },
	{ id = "turtle", name = "Shell Turtle", zone = 4, rarity = "Rare", weight = 25, bonus = "capacity", value = 0.2, archetype = "sea", body = rgb(110, 190, 110), accent = rgb(140, 100, 60), extra = "shell" },
	{ id = "dolphin", name = "Surf Dolphin", zone = 4, rarity = "Epic", weight = 5, bonus = "speed", value = 2, archetype = "sea", body = rgb(110, 170, 230), accent = rgb(230, 245, 255), extra = "fin" },
	-- Zone 5: Frosty Peaks
	{ id = "penguin", name = "Snow Penguin", zone = 5, rarity = "Common", weight = 70, bonus = "capacity", value = 0.15, archetype = "bird", body = rgb(40, 50, 70), accent = rgb(255, 255, 255) },
	{ id = "frostfox", name = "Frost Fox", zone = 5, rarity = "Rare", weight = 25, bonus = "coins", value = 0.3, archetype = "quad", body = rgb(235, 245, 255), accent = rgb(150, 200, 255), ears = "pointy", tail = "bushy" },
	{ id = "yeti", name = "Yeti Pup", zone = 5, rarity = "Legendary", weight = 5, bonus = "radius", value = 2, archetype = "quad", body = rgb(245, 250, 255), accent = rgb(120, 180, 240), ears = "round", tail = "puff", extra = "horns" },
	-- Zone 6: Candy Canyon
	{ id = "gummy", name = "Gummy Bear", zone = 6, rarity = "Common", weight = 70, bonus = "coins", value = 0.15, archetype = "blob", body = rgb(255, 80, 110), accent = rgb(255, 200, 210), ears = "round" },
	{ id = "llama", name = "Lollipop Llama", zone = 6, rarity = "Rare", weight = 25, bonus = "find", value = 0.2, archetype = "quad", body = rgb(255, 240, 250), accent = rgb(255, 120, 200), ears = "long", tail = "puff" },
	{ id = "unicorn", name = "Cotton Candy Unicorn", zone = 6, rarity = "Legendary", weight = 5, bonus = "coins", value = 0.6, archetype = "quad", body = rgb(255, 200, 240), accent = rgb(150, 220, 255), ears = "pointy", tail = "bushy", extra = "horn" },
	-- Zone 7: Volcano Vents
	{ id = "lizard", name = "Ember Lizard", zone = 7, rarity = "Common", weight = 70, bonus = "radius", value = 1, archetype = "sea", body = rgb(230, 90, 40), accent = rgb(255, 200, 80), extra = "tail" },
	{ id = "slime", name = "Magma Slime", zone = 7, rarity = "Rare", weight = 25, bonus = "capacity", value = 0.4, archetype = "blob", body = rgb(255, 110, 30), accent = rgb(60, 40, 40), extra = "glow" },
	{ id = "phoenix", name = "Phoenix Chick", zone = 7, rarity = "Legendary", weight = 5, bonus = "coins", value = 0.8, archetype = "bird", body = rgb(255, 150, 40), accent = rgb(255, 60, 40), ears = "tufts", extra = "glow" },
	-- Zone 8: Moon Base
	{ id = "moonmouse", name = "Moon Mouse", zone = 8, rarity = "Common", weight = 70, bonus = "coins", value = 0.25, archetype = "quad", body = rgb(200, 200, 220), accent = rgb(255, 190, 220), ears = "round", tail = "thin" },
	{ id = "axolotl", name = "Astro Axolotl", zone = 8, rarity = "Epic", weight = 25, bonus = "speed", value = 3, archetype = "sea", body = rgb(255, 170, 220), accent = rgb(170, 110, 255), extra = "gills" },
	{ id = "whale", name = "Cosmic Whale", zone = 8, rarity = "Mythic", weight = 5, bonus = "coins", value = 1.5, archetype = "sea", body = rgb(60, 60, 140), accent = rgb(150, 220, 255), extra = "fin" },
	-- Seasonal: Haunted Hollow (Halloween 2026). zone = 0 keeps them out of normal zone tables.
	{ id = "candybat", name = "Candy Bat", zone = 0, event = "halloween2026", rarity = "Rare", weight = 60, bonus = "coins", value = 0.15, archetype = "bird", body = rgb(110, 60, 160), accent = rgb(255, 140, 40), ears = "tufts" },
	{ id = "ghostpup", name = "Ghost Pup", zone = 0, event = "halloween2026", rarity = "Epic", weight = 30, bonus = "find", value = 0.15, archetype = "quad", body = rgb(240, 245, 255), accent = rgb(170, 210, 255), ears = "round", tail = "puff", extra = "glow" },
	{ id = "jackkitten", name = "Jack-o'-Kitten", zone = 0, event = "halloween2026", rarity = "Legendary", weight = 10, bonus = "coins", value = 0.3, archetype = "quad", body = rgb(250, 130, 30), accent = rgb(40, 30, 40), ears = "pointy", tail = "thin", extra = "glow" },
	-- Seasonal: Snow Day (Winter 2026).
	{ id = "cocoacub", name = "Cocoa Cub", zone = 0, event = "winter2026", rarity = "Rare", weight = 60, bonus = "capacity", value = 0.2, archetype = "quad", body = rgb(120, 75, 50), accent = rgb(255, 245, 230), ears = "round", tail = "puff" },
	{ id = "gingerpup", name = "Gingerbread Pup", zone = 0, event = "winter2026", rarity = "Epic", weight = 30, bonus = "coins", value = 0.2, archetype = "quad", body = rgb(200, 120, 60), accent = rgb(255, 255, 255), ears = "pointy", tail = "thin" },
	{ id = "reindeer", name = "Aurora Reindeer", zone = 0, event = "winter2026", rarity = "Legendary", weight = 10, bonus = "radius", value = 1.5, archetype = "quad", body = rgb(160, 110, 70), accent = rgb(245, 230, 205), ears = "round", tail = "puff", extra = "antlers" },
} :: { Critter }

Critters.ById = {} :: { [string]: Critter }
Critters.ByZone = {} :: { [number]: { Critter } }
for _, critter in Critters.List do
	Critters.ById[critter.id] = critter
	local list = Critters.ByZone[critter.zone]
	if not list then
		list = {}
		Critters.ByZone[critter.zone] = list
	end
	table.insert(list, critter)
end

return Critters
