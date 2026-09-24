--!strict
-- Awards milestone badges (ids in Config/Badges; 0 = not created yet, skipped).
-- Listens to gameplay events so no other service needs to know about badges.

local BadgeServiceRoblox = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage.Shared.Config.Badges)

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Events)

local BadgeService = {}

local byKey: { [string]: Badges.Badge } = {}
for _, badge in Badges do
	byKey[badge.key] = badge
end

local awarded: { [Player]: { [string]: boolean } } = {}

-- Returns true if an award call was made (for tests).
function BadgeService.award(player: Player, key: string): boolean
	local badge = byKey[key]
	if not badge or badge.id == 0 then
		return false
	end
	local cache = awarded[player] or {}
	awarded[player] = cache
	if cache[key] then
		return false
	end
	cache[key] = true
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeServiceRoblox:UserHasBadgeAsync(player.UserId, badge.id)
		end)
		if ok and has then
			return
		end
		local success, err = pcall(function()
			BadgeServiceRoblox:AwardBadge(player.UserId, badge.id)
		end)
		if not success then
			cache[key] = nil -- allow a retry on the next trigger
			warn("[BadgeService] award failed: " .. tostring(err))
		end
	end)
	return true
end

function BadgeService:Init()
	DataService.ProfileLoaded:Connect(function(player)
		BadgeService.award(player, "Welcome")
	end)
	DataService.ProfileReleasing:Connect(function(player)
		awarded[player] = nil
	end)
	Events.CritterFound:Connect(function(player)
		BadgeService.award(player, "FirstCritter")
	end)
	Events.ZoneUnlocked:Connect(function(player, zoneId)
		if zoneId >= 4 then
			BadgeService.award(player, "Zone4")
		end
		if zoneId >= 8 then
			BadgeService.award(player, "AllZones")
		end
	end)
	Events.Rebirthed:Connect(function(player)
		BadgeService.award(player, "FirstRebirth")
	end)
	Events.GoldenMade:Connect(function(player)
		BadgeService.award(player, "GoldenCritter")
	end)
end

return BadgeService
