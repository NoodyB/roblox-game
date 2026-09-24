--!strict
-- Coin shop (vacuum / bag / boots tiers), zone unlocks, teleports, rebirths and perks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Upgrades = require(Shared.Config.Upgrades)
local Progression = require(Shared.Config.Progression)
local Economy = require(Shared.Logic.Economy)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)
local Events = require(script.Parent.Events)
local Analytics = require(script.Parent.Analytics)

local ShopService = {}

local teleportCooldown: { [Player]: number } = {}

function ShopService.buyUpgrade(player: Player, track: any): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "Loading"
	end
	if type(track) ~= "string" or not Economy.TrackField[track] then
		return false, "Unknown upgrade"
	end
	local tier = Economy.nextTier(profile, track)
	local ok, err = Economy.buyNextTier(profile, track)
	if not ok then
		return false, err
	end
	PlayerService.refresh(player)
	Net.fire("Effect", player, "purchase", { text = tier.name .. " equipped!" })
	Events.Upgraded:Fire(player, track, profile[Economy.TrackField[track]])
	Analytics.onboarding(player, "FirstUpgrade")
	Analytics.economy(player, "Sink", tier.cost, profile.coins, "Shop", track .. "_" .. tostring(profile[Economy.TrackField[track]]))
	return true, nil
end

function ShopService.unlockZone(player: Player, zoneId: any): (boolean, string?)
	local profile = DataService.get(player)
	if not profile then
		return false, "Loading"
	end
	if type(zoneId) ~= "number" or not Zones[zoneId] then
		return false, "Unknown zone"
	end
	local ok, err = Economy.unlockZone(profile, zoneId)
	if not ok then
		return false, err
	end
	local zone = Zones[zoneId]
	PlayerService.refresh(player)
	Net.fire("Effect", player, "unlock", { zoneId = zoneId })
	Net.notify(player, "success", zone.emoji .. " " .. zone.name .. " unlocked!")
	Events.ZoneUnlocked:Fire(player, zoneId)
	if zoneId == 2 then
		Analytics.onboarding(player, "UnlockedZone2")
	end
	Analytics.economy(player, "Sink", zone.unlockCost, profile.coins, "Shop", "Zone_" .. zoneId)
	Analytics.progression(player, "Zones", "Complete", zoneId)
	return true, nil
end

function ShopService:Init()
	Net.onAction("BuyUpgrade", ShopService.buyUpgrade)
	Net.onAction("UnlockZone", ShopService.unlockZone)

	Net.onAction("Teleport", function(player, zoneId)
		local profile = DataService.get(player)
		-- integer check also rejects NaN/inf (NaN fails every range comparison)
		if not profile or type(zoneId) ~= "number" or zoneId ~= math.floor(zoneId) or math.abs(zoneId) == math.huge then
			return false, "Invalid zone"
		end
		if zoneId ~= 0 and (zoneId < 1 or zoneId > profile.maxZone) then
			return false, "Zone is locked"
		end
		local now = os.clock()
		if (teleportCooldown[player] or 0) > now then
			return false, "Teleport is recharging"
		end
		teleportCooldown[player] = now + 3
		WorldService.teleport(player, zoneId)
		PlayerService.setGrace(player)
		return true, nil
	end)

	Net.onAction("Rebirth", function(player)
		local profile = DataService.get(player)
		if not profile then
			return false, "Loading"
		end
		local ok, err = Economy.rebirth(profile)
		if not ok then
			return false, err
		end
		PlayerService.refresh(player)
		WorldService.teleport(player, 0)
		PlayerService.setGrace(player)
		Net.fire("Effect", player, "rebirth", { rebirths = profile.rebirths })
		Events.Rebirthed:Fire(player, profile.rebirths)
		if profile.rebirths == 1 then
			Analytics.onboarding(player, "FirstRebirth")
		end
		Analytics.progression(player, "Rebirth", "Complete", profile.rebirths)
		return true, nil
	end)

	Net.onAction("BuyPerk", function(player, perkId)
		local profile = DataService.get(player)
		if not profile or type(perkId) ~= "string" then
			return false, "Invalid perk"
		end
		local ok, err = Economy.buyPerk(profile, perkId)
		if ok then
			PlayerService.refresh(player)
			local perk = Progression.PerksById[perkId]
			Net.fire("Effect", player, "purchase", { text = perk.name .. " upgraded!" })
		end
		return ok, err
	end)

	Net.onAction("RedeemCode", function(player, code)
		local profile = DataService.get(player)
		if not profile then
			return false, "Loading"
		end
		local ok, message = Economy.redeemCode(profile, code, os.time())
		if not ok then
			return false, message
		end
		PlayerService.refresh(player)
		Net.fire("Effect", player, "reward", { text = "🎟️ " .. message })
		Analytics.custom(player, "CodeRedeemed")
		return true, message
	end)

	WorldService.GatePrompted:Connect(function(player: Player, zoneId: number)
		local ok, err = ShopService.unlockZone(player, zoneId)
		if not ok and err then
			Net.notify(player, "error", err)
		end
	end)
end

ShopService.MaxTiers = { Vacuums = #Upgrades.Vacuums, Bags = #Upgrades.Bags, Boots = #Upgrades.Boots }

return ShopService
