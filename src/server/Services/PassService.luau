--!strict
-- Game pass ownership. Roblox is the source of truth: ownership is checked on join (with retries)
-- and updated when a purchase finishes in-game. Passes with id 0 are not configured and ignored.
--
-- Studio testing: set the attribute `GrantAllPasses = true` on ServerScriptService to pretend every
-- configured-or-not pass is owned (only works in Studio).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Products = require(Shared.Config.Products)
local Signal = require(Shared.Util.Signal)

local PassService = {}

PassService.Changed = Signal.new() -- (player)

local owned: { [Player]: { [string]: boolean } } = {}

local function studioGrantAll(): boolean
	return RunService:IsStudio() and ServerScriptService:GetAttribute("GrantAllPasses") == true
end

local function checkOwnership(player: Player)
	local result: { [string]: boolean } = {}
	for _, pass in Products.GamePasses do
		if studioGrantAll() then
			result[pass.key] = true
		elseif pass.id ~= 0 then
			for attempt = 1, 3 do
				local ok, has = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok then
					result[pass.key] = has == true
					break
				end
				task.wait(attempt)
			end
		end
	end
	if player.Parent then
		owned[player] = result
		PassService.Changed:Fire(player)
	end
end

function PassService.passes(player: Player): { [string]: boolean }
	return owned[player] or {}
end

function PassService.owns(player: Player, key: string): boolean
	local list = owned[player]
	return list ~= nil and list[key] == true
end

function PassService:Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(checkOwnership, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(checkOwnership, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Products.PassById[passId]
		if not pass then
			return
		end
		-- Re-verify with Roblox rather than trusting the event payload alone.
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if (ok and has) or not ok then
			-- If the check itself failed, the purchase event is still authoritative from Roblox.
			local list = owned[player] or {}
			list[pass.key] = true
			owned[player] = list
			PassService.Changed:Fire(player)
		end
	end)
end

PassService._checkOwnership = checkOwnership

return PassService
