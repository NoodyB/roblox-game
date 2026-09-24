--!nocheck
-- In-memory stand-ins for Roblox engine services used by server code under test.
-- They model the documented semantics that matter for correctness (UpdateAsync transforms that can
-- cancel by returning nil, serialization copies, request failures, signals), nothing more.

local task = require("@lune/task")

local Mocks = {}

---------------------------------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------------------------------

function Mocks.signal()
	local handlers = {}
	local waiters = {}
	local sig = {}
	function sig:Wait()
		table.insert(waiters, coroutine.running())
		return coroutine.yield()
	end
	function sig:Connect(fn)
		local entry = { fn = fn, connected = true }
		table.insert(handlers, entry)
		return {
			Connected = true,
			Disconnect = function(conn)
				entry.connected = false
				conn.Connected = false
			end,
		}
	end
	function sig:Fire(...)
		for _, entry in table.clone(handlers) do
			if entry.connected then
				entry.fn(...)
			end
		end
		local pending = waiters
		waiters = {}
		for _, thread in pending do
			task.spawn(thread, ...)
		end
	end
	function sig:Once(fn)
		local conn
		conn = sig:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	return sig
end

---------------------------------------------------------------------------------------------------
-- Generic instance (used when server code calls Instance.new in logic tests)
---------------------------------------------------------------------------------------------------

local instanceData = setmetatable({}, { __mode = "k" })
local methods = {}

function Mocks.instance(className: string, props)
	local data = {
		ClassName = className,
		Name = className,
		Parent = nil,
		children = {},
		attributes = {},
		tags = {},
		props = props or {},
		destroyed = false,
	}
	local inst = {}
	instanceData[inst] = data
	setmetatable(inst, {
		__index = function(self, key)
			local d = instanceData[self]
			if key == "ClassName" or key == "Name" or key == "Parent" then
				return d[key]
			end
			if d.props[key] ~= nil then
				return d.props[key]
			end
			if methods[key] then
				return methods[key]
			end
			for _, child in d.children do
				if instanceData[child].Name == key then
					return child
				end
			end
			return nil
		end,
		__newindex = function(self, key, value)
			local d = instanceData[self]
			if key == "Parent" then
				if d.Parent and instanceData[d.Parent] then
					local siblings = instanceData[d.Parent].children
					local index = table.find(siblings, self)
					if index then
						table.remove(siblings, index)
					end
				end
				d.Parent = value
				if value and instanceData[value] then
					table.insert(instanceData[value].children, self)
				end
			elseif key == "Name" or key == "ClassName" then
				d[key] = value
			else
				d.props[key] = value
			end
		end,
		__tostring = function(self)
			return instanceData[self].Name
		end,
	})
	return inst
end

function methods.FindFirstChild(self, name)
	for _, child in instanceData[self].children do
		if instanceData[child].Name == name then
			return child
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, className)
	for _, child in instanceData[self].children do
		if instanceData[child].ClassName == className then
			return child
		end
	end
	return nil
end
function methods.WaitForChild(self, name)
	return methods.FindFirstChild(self, name)
end
function methods.GetChildren(self)
	return table.clone(instanceData[self].children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, c in instanceData[node].children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.IsA(self, className)
	return instanceData[self].ClassName == className
end
function methods.Destroy(self)
	instanceData[self].destroyed = true
	self.Parent = nil
end
function methods.SetAttribute(self, name, value)
	instanceData[self].attributes[name] = value
end
function methods.GetAttribute(self, name)
	return instanceData[self].attributes[name]
end
function methods.AddTag(self, tag)
	instanceData[self].tags[tag] = true
end
function methods.PivotTo(self, cframe)
	instanceData[self].props.pivot = cframe
end

Mocks.Instance = {
	new = function(className: string)
		return Mocks.instance(className)
	end,
}

---------------------------------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------------------------------

function Mocks.players()
	local list = {}
	local service = {
		PlayerAdded = Mocks.signal(),
		PlayerRemoving = Mocks.signal(),
	}
	function service:GetPlayers()
		return table.clone(list)
	end
	function service:GetPlayerByUserId(userId)
		for _, p in list do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end
	function service:GetNameFromUserIdAsync(userId)
		return "User" .. tostring(userId)
	end
	-- test helpers
	function service.add(userId: number, name: string?)
		local player = Mocks.instance("Player", {
			UserId = userId,
			DisplayName = name or ("Player" .. userId),
			CharacterAdded = Mocks.signal(),
			Character = nil,
		})
		player.Name = name or ("Player" .. userId)
		player.Parent = service -- non-nil Parent means "in game"
		player.kicked = nil
		player.Kick = function(self, message)
			self.kicked = message or true
		end
		table.insert(list, player)
		return player
	end
	function service.remove(player)
		local index = table.find(list, player)
		if index then
			table.remove(list, index)
		end
		service.PlayerRemoving:Fire(player)
		player.Parent = nil
	end
	return service
end

---------------------------------------------------------------------------------------------------
-- DataStoreService
---------------------------------------------------------------------------------------------------

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[deepCopy(k)] = deepCopy(v)
	end
	return out
end
Mocks.deepCopy = deepCopy

function Mocks.dataStoreService(options)
	options = options or {}
	local stores = {}
	local service = { unavailable = options.unavailable == true }

	local function makeStore(name)
		local store = { name = name, data = {}, failNext = 0, writes = 0 }
		local function maybeFail()
			if store.failNext > 0 then
				store.failNext -= 1
				error("mock DataStore failure")
			end
		end
		function store:GetAsync(key)
			maybeFail()
			return deepCopy(store.data[key])
		end
		function store:SetAsync(key, value)
			maybeFail()
			store.writes += 1
			store.data[key] = deepCopy(value)
		end
		function store:UpdateAsync(key, transform)
			maybeFail()
			local result = transform(deepCopy(store.data[key]))
			if result ~= nil then
				store.writes += 1
				store.data[key] = deepCopy(result)
			end
			return deepCopy(result)
		end
		function store:GetSortedAsync(ascending, pageSize)
			maybeFail()
			local entries = {}
			for key, value in store.data do
				table.insert(entries, { key = key, value = value })
			end
			table.sort(entries, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #entries) do
				page[i] = entries[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
			}
		end
		return store
	end

	function service:GetDataStore(name)
		if service.unavailable then
			error("DataStoreService unavailable (mock)")
		end
		stores[name] = stores[name] or makeStore(name)
		return stores[name]
	end
	service.GetOrderedDataStore = service.GetDataStore
	function service.store(name)
		stores[name] = stores[name] or makeStore(name)
		return stores[name]
	end
	return service
end

---------------------------------------------------------------------------------------------------
-- Misc services
---------------------------------------------------------------------------------------------------

function Mocks.marketplace()
	return {
		ProcessReceipt = nil,
		PromptGamePassPurchaseFinished = Mocks.signal(),
		ownership = {},
		UserOwnsGamePassAsync = function(self, userId, passId)
			return self.ownership[userId .. ":" .. passId] == true
		end,
	}
end

function Mocks.runService(isStudio: boolean?)
	return {
		Heartbeat = Mocks.signal(),
		IsStudio = function()
			return isStudio == true
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	}
end

function Mocks.analytics()
	local calls = {}
	local service = { calls = calls }
	setmetatable(service, {
		__index = function(_, key)
			return function(_, ...)
				table.insert(calls, { method = key, args = { ... } })
			end
		end,
	})
	return service
end

function Mocks.workspace()
	local ws = Mocks.instance("Workspace")
	ws.serverTime = 1000
	ws.GetServerTimeNow = function(self)
		return self.serverTime
	end
	return ws
end

-- Installs a full set of engine mocks into the harness. Returns them for inspection.
function Mocks.install(Harness, options)
	options = options or {}
	local m = {
		Players = Mocks.players(),
		DataStoreService = Mocks.dataStoreService(options),
		MarketplaceService = Mocks.marketplace(),
		RunService = Mocks.runService(options.studio),
		AnalyticsService = Mocks.analytics(),
		Workspace = Mocks.workspace(),
	}
	for name, service in m do
		Harness.setService(name, service)
	end
	Harness.globals.Instance = Mocks.Instance
	return m
end

return Mocks
