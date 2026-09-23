--!strict
-- Linear upgrade tracks. The player owns tier N and may buy tier N + 1.
-- Costs are in coins. Tier 1 is always free/owned.

export type VacuumTier = { name: string, radius: number, power: number, cost: number, color: Color3 }
export type BagTier = { name: string, capacity: number, cost: number, color: Color3 }
export type BootsTier = { name: string, speed: number, cost: number, color: Color3 }

local rgb = Color3.fromRGB

local Upgrades = {}

Upgrades.Vacuums = {
	{ name = "Rusty Rake", radius = 5, power = 1, cost = 0, color = rgb(160, 110, 70) },
	{ name = "Twig Broom", radius = 6, power = 1, cost = 60, color = rgb(196, 150, 90) },
	{ name = "Leaf Blower", radius = 7, power = 2, cost = 350, color = rgb(255, 150, 60) },
	{ name = "Hand Vac", radius = 8.5, power = 2, cost = 1_800, color = rgb(90, 170, 255) },
	{ name = "Turbo Vac", radius = 10, power = 3, cost = 9_000, color = rgb(80, 210, 140) },
	{ name = "Cyclone Vac", radius = 11.5, power = 4, cost = 45_000, color = rgb(120, 110, 255) },
	{ name = "Storm Sucker", radius = 13, power = 5, cost = 220_000, color = rgb(60, 90, 200) },
	{ name = "Tornado 3000", radius = 15, power = 6, cost = 1_100_000, color = rgb(230, 70, 90) },
	{ name = "Black Hole Vac", radius = 17, power = 8, cost = 6_500_000, color = rgb(40, 30, 60) },
	{ name = "Galaxy Gobbler", radius = 20, power = 10, cost = 40_000_000, color = rgb(170, 90, 255) },
	{ name = "Quantum Void", radius = 23, power = 12, cost = 260_000_000, color = rgb(20, 220, 220) },
	{ name = "Cosmic Cleaner", radius = 26, power = 15, cost = 1_800_000_000, color = rgb(255, 210, 60) },
} :: { VacuumTier }

Upgrades.Bags = {
	{ name = "Paper Sack", capacity = 40, cost = 0, color = rgb(200, 170, 120) },
	{ name = "Trash Bag", capacity = 100, cost = 50, color = rgb(60, 60, 70) },
	{ name = "Burlap Sack", capacity = 250, cost = 300, color = rgb(170, 130, 80) },
	{ name = "Duffel Bag", capacity = 600, cost = 1_600, color = rgb(70, 110, 200) },
	{ name = "Hiker Pack", capacity = 1_500, cost = 8_000, color = rgb(90, 150, 70) },
	{ name = "Mega Tote", capacity = 4_000, cost = 40_000, color = rgb(230, 90, 150) },
	{ name = "Cargo Pod", capacity = 10_000, cost = 200_000, color = rgb(240, 170, 40) },
	{ name = "Titan Tank", capacity = 25_000, cost = 1_000_000, color = rgb(120, 130, 140) },
	{ name = "Mini Black Hole", capacity = 60_000, cost = 6_000_000, color = rgb(50, 30, 70) },
	{ name = "Pocket Dimension", capacity = 150_000, cost = 38_000_000, color = rgb(150, 100, 255) },
	{ name = "Nebula Satchel", capacity = 400_000, cost = 240_000_000, color = rgb(255, 120, 220) },
	{ name = "Star Sack", capacity = 1_000_000, cost = 1_600_000_000, color = rgb(255, 220, 90) },
} :: { BagTier }

Upgrades.Boots = {
	{ name = "Old Sneakers", speed = 18, cost = 0, color = rgb(180, 180, 180) },
	{ name = "Rain Boots", speed = 20, cost = 150, color = rgb(255, 210, 60) },
	{ name = "Trail Runners", speed = 22, cost = 1_500, color = rgb(80, 200, 120) },
	{ name = "Spring Soles", speed = 24, cost = 14_000, color = rgb(90, 160, 255) },
	{ name = "Jet Kicks", speed = 26, cost = 130_000, color = rgb(255, 110, 60) },
	{ name = "Hover Heels", speed = 28, cost = 1_200_000, color = rgb(170, 110, 255) },
	{ name = "Comet Treads", speed = 30, cost = 11_000_000, color = rgb(60, 220, 230) },
	{ name = "Warp Walkers", speed = 32, cost = 100_000_000, color = rgb(255, 220, 90) },
} :: { BootsTier }

Upgrades.Tracks = { "Vacuums", "Bags", "Boots" }

return Upgrades
