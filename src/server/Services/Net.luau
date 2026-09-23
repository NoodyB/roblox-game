--!strict
-- Server networking: creates remotes, dispatches validated + rate-limited client actions,
-- and only sends updates to clients that finished their handshake ("Hello").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local RateLimiter = require(Shared.Util.RateLimiter)

type Handler = (player: Player, payload: any) -> (boolean, any)

local Net = {}

local events: { [string]: RemoteEvent } = {}
local handlers: { [string]: Handler } = {}
local allowed: { [string]: boolean } = {}
local ready: { [Player]: boolean } = {}
local limiter = RateLimiter.new(GameConfig.RemoteRate, GameConfig.RemoteBurst)

for _, name in Remotes.Actions do
	allowed[name] = true
end

local function dispatch(player: Player, action: any, payload: any)
	if type(action) ~= "string" or not allowed[action] then
		return { ok = false, err = "Unknown action" }
	end
	local handler = handlers[action]
	if not handler then
		return { ok = false, err = "Unavailable" }
	end
	if not limiter:check(player) then
		return { ok = false, err = "Slow down!" }
	end
	local success, ok, result = pcall(handler, player, payload)
	if not success then
		warn(string.format("[Net] action %s failed for %s: %s", action, player.Name, tostring(ok)))
		return { ok = false, err = "Something went wrong" }
	end
	if ok then
		return { ok = true, data = result }
	end
	return { ok = false, err = if type(result) == "string" then result else "Not allowed" }
end
Net._dispatch = dispatch -- exposed for tests

function Net:Init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for _, name in Remotes.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		events[name] = remote
	end
	local actionFn = Instance.new("RemoteFunction")
	actionFn.Name = Remotes.ActionFunction
	actionFn.OnServerInvoke = dispatch
	actionFn.Parent = folder
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		limiter:remove(player)
	end)
end

function Net.onAction(action: string, handler: Handler)
	assert(allowed[action], "Action not declared in Remotes.Actions: " .. action)
	assert(handlers[action] == nil, "Duplicate handler for " .. action)
	handlers[action] = handler
end

function Net.setReady(player: Player)
	ready[player] = true
end

function Net.isReady(player: Player): boolean
	return ready[player] == true
end

function Net.fire(name: string, player: Player, ...: any)
	local remote = events[name]
	if remote and ready[player] and player.Parent then
		remote:FireClient(player, ...)
	end
end

function Net.fireAll(name: string, ...: any)
	local remote = events[name]
	if not remote then
		return
	end
	for player in ready do
		if player.Parent then
			remote:FireClient(player, ...)
		end
	end
end

function Net.notify(player: Player, kind: string, text: string)
	Net.fire("Notify", player, kind, text)
end

return Net
