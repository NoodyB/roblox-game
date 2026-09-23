--!strict
-- Critter finds (rolled server-side on collecting ticks), equipping and golden merging.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Critters = require(Shared.Config.Critters)
local CritterLogic = require(Shared.Logic.CritterLogic)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Events = require(script.Parent.Events)
local Analytics = require(script.Parent.Analytics)

local CritterService = {}

local random = Random.new()
local function roll(): number
	return random:NextNumber()
end

function CritterService.grant(player: Player, critterId: string)
	local profile = DataService.get(player)
	local stats = PlayerService.getStats(player)
	if not profile or not stats or not Critters.ById[critterId] then
		return
	end
	local isNew = not profile.discovered[critterId]
	CritterLogic.add(profile, critterId)
	profile.stats.crittersFound += 1
	profile.stats.ticksSinceCritter = 0
	-- auto-equip into a free slot so new players immediately see (and benefit from) their critter
	if #profile.equipped < stats.equipSlots then
		table.insert(profile.equipped, critterId)
	end
	PlayerService.refresh(player)
	Net.fire("Effect", player, "critter", { id = critterId, isNew = isNew })
	Events.CritterFound:Fire(player, critterId)
	if profile.stats.crittersFound == 1 then
		Analytics.onboarding(player, "FirstCritter")
	end
	Analytics.custom(player, "CritterFound_" .. Critters.ById[critterId].rarity)
end

function CritterService.onCollectTick(player: Player, zoneId: number)
	local profile = DataService.get(player)
	local stats = PlayerService.getStats(player)
	if not profile or not stats then
		return
	end
	profile.stats.ticksSinceCritter += 1
	local found = CritterLogic.roll(
		roll,
		zoneId,
		stats.findMultiplier,
		profile.stats.ticksSinceCritter,
		profile.stats.crittersFound == 0
	)
	if found then
		CritterService.grant(player, found)
	end
end

function CritterService:Init()
	Net.onAction("EquipCritters", function(player, list)
		local profile = DataService.get(player)
		local stats = PlayerService.getStats(player)
		if not profile or not stats then
			return false, "Loading"
		end
		local ok, err = CritterLogic.setEquipped(profile, list, stats.equipSlots)
		if ok then
			PlayerService.refresh(player)
		end
		return ok, err
	end)

	Net.onAction("AutoEquip", function(player)
		local profile = DataService.get(player)
		local stats = PlayerService.getStats(player)
		if not profile or not stats then
			return false, "Loading"
		end
		profile.equipped = CritterLogic.bestLoadout(profile, stats.equipSlots)
		PlayerService.refresh(player)
		return true, nil
	end)

	Net.onAction("MakeGolden", function(player, critterId)
		local profile = DataService.get(player)
		if not profile or type(critterId) ~= "string" then
			return false, "Invalid critter"
		end
		local ok, err = CritterLogic.makeGolden(profile, critterId)
		if ok then
			PlayerService.refresh(player)
			Net.fire("Effect", player, "golden", { id = critterId })
		end
		return ok, err
	end)
end

return CritterService
