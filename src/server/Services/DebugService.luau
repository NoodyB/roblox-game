--!strict
-- Studio-only test helpers, driven by attributes so no code is needed.
-- During a Studio Play session, select your Player (Explorer → Players → <you>, Server view) and
-- add any of these attributes:
--   DebugCoins    (number)  set your coins to this value
--   DebugMaxZone  (number)  unlock zones up to this id (1-8)
--   DebugCritters (boolean) grant one of every critter
--   DebugTokens   (number)  set rebirth tokens
-- Inert in live servers (RunService:IsStudio() is false there).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Config.Zones)
local Critters = require(Shared.Config.Critters)
local CritterLogic = require(Shared.Logic.CritterLogic)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local DebugService = {}

local HANDLERS: { [string]: (profile: any, value: any) -> () } = {
	DebugCoins = function(profile, value)
		if type(value) == "number" and value >= 0 then
			profile.coins = value
		end
	end,
	DebugMaxZone = function(profile, value)
		if type(value) == "number" then
			profile.maxZone = math.clamp(math.floor(value), 1, #Zones)
		end
	end,
	DebugCritters = function(profile, value)
		if value == true then
			for _, critter in Critters.List do
				CritterLogic.add(profile, critter.id)
			end
		end
	end,
	DebugTokens = function(profile, value)
		if type(value) == "number" and value >= 0 then
			profile.rebirthTokens = math.floor(value)
		end
	end,
}

local function watch(player: Player)
	for attribute, handler in HANDLERS do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			local profile = DataService.get(player)
			if profile then
				handler(profile, player:GetAttribute(attribute))
				PlayerService.refresh(player)
				warn(string.format("[DebugService] applied %s for %s", attribute, player.Name))
			end
		end)
	end
end

function DebugService:Init()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return DebugService
