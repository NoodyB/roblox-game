--!nocheck
-- A client-side test environment. Client code gets `Instance.new` that returns proxies around
-- real Lune instances: every property write is validated against the Roblox reflection database,
-- while events and engine-only methods (tweens, sounds, pivots, signals) are stubbed.

local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3
local Mocks = require("./mocks")

local ClientEnv = {}

-- Simulated screen size (read by Camera.ViewportSize); UI previews change it per device.
ClientEnv.viewport = Vector2.new(1280, 720)

-- Strong tables on purpose: a proxy must stay identical for the lifetime of its instance,
-- otherwise signals connected on one proxy would not fire on another.
local proxyToReal = {}
local realToProxy = {}
local signals = {}

-- Events used by the client code. Anything else that fails to resolve is a real error.
local EVENTS = {
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton1Click = true,
	MouseEnter = true,
	MouseLeave = true,
	Activated = true,
	Changed = true,
	Triggered = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	AncestryChanged = true,
	OnClientEvent = true,
	Completed = true,
	Touched = true,
	InputBegan = true,
	PromptTriggered = true,
}

local wrap

local function unwrap(value)
	if type(value) == "table" and proxyToReal[value] then
		return proxyToReal[value]
	end
	return value
end

local function signalFor(proxy, name)
	signals[proxy] = signals[proxy] or {}
	local s = signals[proxy][name]
	if not s then
		s = Mocks.signal()
		s.Wait = function()
			return nil
		end
		signals[proxy][name] = s
	end
	return s
end

local overrides = {}
function overrides.GetPropertyChangedSignal(self, name)
	return signalFor(self, "prop:" .. name)
end
function overrides.GetAttributeChangedSignal(self, name)
	return signalFor(self, "attr:" .. name)
end
function overrides.WaitForChild(self, name)
	local child = proxyToReal[self]:FindFirstChild(name)
	if not child then
		error("WaitForChild would yield forever: " .. name, 2)
	end
	return wrap(child)
end
function overrides.PivotTo(self, cframe)
	local real = proxyToReal[self]
	if real:IsA("Model") and real.PrimaryPart then
		real.PrimaryPart.CFrame = cframe
	end
end
function overrides.Emit() end
function overrides.Play() end
function overrides.Stop() end
function overrides.Pause() end
function overrides.GetServerTimeNow()
	return os.time()
end
function overrides.IsLoaded()
	return true
end
function overrides.RemoveDefaultLoadingScreen() end

wrap = function(value)
	if typeof(value) ~= "Instance" then
		return value
	end
	local existing = realToProxy[value]
	if existing then
		return existing
	end
	local proxy = {}
	proxyToReal[proxy] = value
	realToProxy[value] = proxy
	setmetatable(proxy, {
		__index = function(self, key)
			local real = proxyToReal[self]
			if overrides[key] then
				return overrides[key]
			end
			if EVENTS[key] then
				return signalFor(self, key)
			end
			local ok, result = pcall(function()
				return real[key]
			end)
			if not ok then
				-- runtime-only properties the file format (and so Lune) doesn't model
				if key == "ViewportSize" then
					return ClientEnv.viewport
				elseif key == "AbsoluteSize" then
					return Vector2.new(100, 100)
				elseif key == "AbsolutePosition" then
					return Vector2.new(0, 0)
				elseif key == "Position" and real:IsA("BasePart") then
					return real.CFrame.Position
				elseif key == "AssemblyLinearVelocity" and real:IsA("BasePart") then
					return Vector3.zero
				end
				error(string.format("%s is not a valid member of %s (%s)", tostring(key), real.ClassName, real.Name), 2)
			end
			if type(result) == "function" then
				return function(_, ...)
					local args = table.pack(...)
					for i = 1, args.n do
						args[i] = unwrap(args[i])
					end
					local out = table.pack(result(real, table.unpack(args, 1, args.n)))
					for i = 1, out.n do
						if type(out[i]) == "table" then
							for k, v in out[i] do
								out[i][k] = wrap(v)
							end
						else
							out[i] = wrap(out[i])
						end
					end
					return table.unpack(out, 1, out.n)
				end
			end
			return wrap(result)
		end,
		__newindex = function(self, key, value)
			local real = proxyToReal[self]
			if key == "OnServerInvoke" or key == "OnClientInvoke" then
				return
			end
			real[key] = unwrap(value)
			local s = signals[self] and signals[self]["prop:" .. key]
			if s then
				s:Fire()
			end
		end,
		__tostring = function(self)
			return proxyToReal[self].Name
		end,
	})
	return proxy
end
ClientEnv.wrap = wrap
ClientEnv.unwrap = unwrap

ClientEnv.Instance = {
	new = function(className, parent)
		local real = roblox.Instance.new(className)
		if parent then
			real.Parent = unwrap(parent)
		end
		return wrap(real)
	end,
}

function ClientEnv.tweenService()
	local created = {}
	return {
		created = created,
		Create = function(_, instance, _info, goals)
			local real = unwrap(instance)
			for key, value in goals do
				real[key] = value -- validates goal names/types
			end
			table.insert(created, instance)
			local completed = Mocks.signal()
			return {
				Completed = completed,
				Play = function()
					task.defer(function()
						completed:Fire()
					end)
				end,
				Cancel = function() end,
			}
		end,
	}
end

-- Installs client mocks into the harness. Returns handles for tests.
function ClientEnv.install(Harness)
	local env = {}
	Harness.globals.Instance = ClientEnv.Instance

	local playersRoot = roblox.Instance.new("Players")
	local player = roblox.Instance.new("Player")
	player.Name = "Tester"
	player.Parent = playersRoot
	local playerGui = roblox.Instance.new("PlayerGui")
	playerGui.Parent = player
	local playersService = Mocks.players()
	playersService.LocalPlayer = wrap(player)
	env.player = playersService.LocalPlayer
	env.playerGui = wrap(playerGui)

	local workspace = roblox.Instance.new("Workspace")
	env.workspace = wrap(workspace)
	local lighting = roblox.Instance.new("Lighting")
	local atmosphere = roblox.Instance.new("Atmosphere")
	atmosphere.Parent = lighting
	local correction = roblox.Instance.new("ColorCorrectionEffect")
	correction.Parent = lighting

	-- remotes the client expects under ReplicatedStorage.Remotes
	local remotes = roblox.Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, name in { "State", "DebrisDelta", "ZoneWave", "Notify", "Effect" } do
		local e = roblox.Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = remotes
	end
	local actionFn = roblox.Instance.new("RemoteFunction")
	actionFn.Name = "Action"
	actionFn.Parent = remotes
	env.remotes = wrap(remotes)
	env.requests = {}
	env.requestHandler = function(action, payload)
		table.insert(env.requests, { action = action, payload = payload })
		return { ok = true, data = nil }
	end
	overrides.InvokeServer = function(_, action, payload)
		return env.requestHandler(action, payload)
	end
	Harness.attach(Harness.findPath("ReplicatedStorage"), "Remotes", env.remotes)

	env.tween = ClientEnv.tweenService()
	local runService = Mocks.runService(false)
	runService.RenderStepped = Mocks.signal()
	runService.Heartbeat.Wait = function()
		return 1 / 60
	end
	runService.IsClient = function()
		return true
	end

	Harness.setService("Players", playersService)
	Harness.setService("Workspace", env.workspace)
	Harness.setService("Lighting", wrap(lighting))
	Harness.setService("SoundService", wrap(roblox.Instance.new("SoundService")))
	Harness.setService("TweenService", env.tween)
	Harness.setService("RunService", runService)
	Harness.setService("UserInputService", {
		TouchEnabled = ClientEnv.touch == true,
		KeyboardEnabled = ClientEnv.touch ~= true,
		InputBegan = Mocks.signal(),
		GetFocusedTextBox = function()
			return nil
		end,
	})
	Harness.setService("CollectionService", {
		GetTagged = function()
			return {}
		end,
		GetInstanceAddedSignal = function()
			return Mocks.signal()
		end,
	})
	env.marketplace = {
		prompts = {},
		GetProductInfo = function(_, id)
			return { PriceInRobux = 99, ProductId = id }
		end,
		PromptProductPurchase = function(self, _, id)
			table.insert(self.prompts, id)
		end,
		PromptGamePassPurchase = function(self, _, id)
			table.insert(self.prompts, id)
		end,
	}
	Harness.setService("MarketplaceService", env.marketplace)
	Harness.setService("ProximityPromptService", { PromptTriggered = Mocks.signal() })
	env.textChat = { OnIncomingMessage = nil }
	Harness.setService("SocialService", {
		CanSendGameInviteAsync = function()
			return true
		end,
		PromptGameInvite = function() end,
	})
	Harness.setService("TextChatService", env.textChat)
	Harness.setService("StarterGui", {
		SetCoreGuiEnabled = function() end,
	})
	return env
end

return ClientEnv
