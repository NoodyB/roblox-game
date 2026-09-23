--!strict
-- Builds the map at startup and owns world interactions: gate prompts, teleports, leaderboards.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local MapBuilder = require(Shared.World.MapBuilder)
local Signal = require(Shared.Util.Signal)

local WorldService = {}

WorldService.GatePrompted = Signal.new() -- (player, zoneId)

local refs: MapBuilder.MapRefs? = nil

function WorldService:Init()
	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	refs = MapBuilder.build(Workspace)
	local built = refs :: MapBuilder.MapRefs
	for _, prompt in built.prompts do
		local zoneId = prompt:GetAttribute("ZoneId")
		if type(zoneId) == "number" then
			prompt.Triggered:Connect(function(player: Player)
				WorldService.GatePrompted:Fire(player, zoneId)
			end)
		end
	end
	Workspace:SetAttribute("MapReady", true)
end

-- Moves a player's character to a zone's arrival point (0 = hub), facing into the zone.
function WorldService.teleport(player: Player, zoneId: number)
	local character = player.Character
	if not character then
		return
	end
	local x, z = ZoneLayout.spawnPoint(zoneId)
	local position = Vector3.new(x, MapBuilder.GroundTop + 3.5, z)
	character:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
end

function WorldService.setBoard(key: string, title: string, entries: { { rank: number, name: string, value: string } })
	local board = refs and refs.boards[key]
	if not board then
		return
	end
	board.title.Text = title
	for i, row in board.rows do
		local entry = entries[i]
		row.Text = if entry then string.format("#%d  %s  —  %s", entry.rank, entry.name, entry.value) else ""
	end
	if #entries == 0 and board.rows[1] then
		board.rows[1].Text = "Be the first on the board!"
	end
end

return WorldService
