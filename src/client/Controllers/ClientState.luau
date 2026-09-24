--!strict
-- Client mirror of the player's state + the request pipe to the server.
-- The server is authoritative: the client only displays `state` and asks for actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)

local ClientState = {}

ClientState.state = nil :: { [string]: any }?
ClientState.Changed = Signal.new() -- (state)
ClientState.Ready = Signal.new() -- (state, debrisSnapshot)
ClientState.Effect = Signal.new() -- (kind, payload)
ClientState.Notify = Signal.new() -- (kind, text)
ClientState.isReady = false

local folder: Folder
local actionFn: RemoteFunction

function ClientState.remote(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Sends an action to the server. Returns ok, data-or-error. Errors are also shown as toasts
-- unless `quiet` is set.
function ClientState.request(action: string, payload: any?, quiet: boolean?): (boolean, any)
	local ok, result = pcall(function()
		return actionFn:InvokeServer(action, payload)
	end)
	if not ok or type(result) ~= "table" then
		if not quiet then
			ClientState.Notify:Fire("error", "Connection hiccup, try again!")
		end
		return false, "network"
	end
	if not result.ok and not quiet and result.err then
		ClientState.Notify:Fire("error", result.err)
	end
	return result.ok == true, if result.ok then result.data else result.err
end

local function applyState(state: { [string]: any })
	ClientState.state = state
	ClientState.Changed:Fire(state)
end

function ClientState:Init()
	folder = ReplicatedStorage:WaitForChild(Remotes.FolderName) :: Folder
	actionFn = folder:WaitForChild(Remotes.ActionFunction) :: RemoteFunction
	ClientState.remote("State").OnClientEvent:Connect(applyState)
	ClientState.remote("Effect").OnClientEvent:Connect(function(kind, payload)
		ClientState.Effect:Fire(kind, payload)
	end)
	ClientState.remote("Notify").OnClientEvent:Connect(function(kind, text)
		ClientState.Notify:Fire(kind, text)
	end)
end

-- Handshake: retried until the server has loaded our profile.
function ClientState:Start()
	task.spawn(function()
		local attempts = 0
		while Players.LocalPlayer.Parent do
			attempts += 1
			local ok, data = ClientState.request("Hello", nil, true)
			if ok and type(data) == "table" then
				ClientState.isReady = true
				applyState(data.state)
				ClientState.Ready:Fire(data.state, data.debris)
				return
			end
			if attempts == 20 then
				ClientState.Notify:Fire("error", "Still loading your save…")
			end
			task.wait(math.min(0.5 + attempts * 0.25, 3))
		end
	end)
end

return ClientState
