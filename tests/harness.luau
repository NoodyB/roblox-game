--!nocheck
-- Offline test harness: loads the Rojo project into a virtual instance tree so ModuleScripts can be
-- required with Roblox-style paths (script.Parent.X, game:GetService("ReplicatedStorage").Shared...).
-- Real Roblox datatypes and Instance.new come from Lune's roblox library, which validates class and
-- property names against the Roblox reflection database. Services that need the Roblox engine
-- (Players, DataStoreService, MarketplaceService, ...) are provided by tests/mocks.luau.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = {}

---------------------------------------------------------------------------------------------------
-- Virtual instances
---------------------------------------------------------------------------------------------------

local internals = setmetatable({}, { __mode = "k" })
local VNodeMethods = {}

local function isVNode(value)
	return type(value) == "table" and internals[value] ~= nil
end
Harness.isVNode = isVNode

local function newVNode(name: string, className: string, parent, source: string?, path: string?)
	local node = {}
	internals[node] = {
		Name = name,
		ClassName = className,
		Parent = parent,
		children = {},
		source = source,
		path = path,
		attributes = {},
		props = {},
		external = {},
	}
	setmetatable(node, {
		__index = function(self, key)
			local data = internals[self]
			if key == "Name" or key == "ClassName" or key == "Parent" then
				return data[key]
			end
			if data.props[key] ~= nil then
				return data.props[key]
			end
			if VNodeMethods[key] then
				return VNodeMethods[key]
			end
			for _, child in data.children do
				if internals[child].Name == key then
					return child
				end
			end
			if data.external[key] ~= nil then
				return data.external[key]
			end
			error(string.format("%s is not a valid member of %s", tostring(key), VNodeMethods.GetFullName(self)), 2)
		end,
		__newindex = function(self, key, value)
			local data = internals[self]
			if key == "Name" then
				data.Name = value
			elseif key == "Parent" then
				if data.Parent then
					local siblings = internals[data.Parent].children
					local index = table.find(siblings, self)
					if index then
						table.remove(siblings, index)
					end
				end
				data.Parent = value
				if value then
					table.insert(internals[value].children, self)
				end
			else
				error("Cannot set " .. tostring(key) .. " on virtual instance", 2)
			end
		end,
		__tostring = function(self)
			return internals[self].Name
		end,
	})
	if parent then
		table.insert(internals[parent].children, node)
	end
	return node
end

function VNodeMethods.FindFirstChild(self, name)
	for _, child in internals[self].children do
		if internals[child].Name == name then
			return child
		end
	end
	return internals[self].external[name]
end

function VNodeMethods.WaitForChild(self, name)
	local child = VNodeMethods.FindFirstChild(self, name)
	if not child then
		error("WaitForChild would yield forever: " .. VNodeMethods.GetFullName(self) .. "." .. name, 2)
	end
	return child
end

function VNodeMethods.GetChildren(self)
	return table.clone(internals[self].children)
end

function VNodeMethods.GetDescendants(self)
	local result = {}
	local function walk(node)
		for _, child in internals[node].children do
			table.insert(result, child)
			walk(child)
		end
	end
	walk(self)
	return result
end

function VNodeMethods.IsA(self, className)
	local own = internals[self].ClassName
	if own == className then
		return true
	end
	if className == "LuaSourceContainer" or className == "BaseScript" then
		return own == "ModuleScript" or own == "Script" or own == "LocalScript"
	end
	return className == "Instance"
end

function VNodeMethods.GetFullName(self)
	local parts = {}
	local node = self
	while node do
		table.insert(parts, 1, internals[node].Name)
		node = internals[node].Parent
	end
	return table.concat(parts, ".")
end

function VNodeMethods.GetAttribute(self, name)
	return internals[self].attributes[name]
end

function VNodeMethods.SetAttribute(self, name, value)
	internals[self].attributes[name] = value
end

---------------------------------------------------------------------------------------------------
-- Build the tree from default.project.json
---------------------------------------------------------------------------------------------------

local function classify(fileName: string): (string?, string?)
	local base = string.match(fileName, "^(.+)%.server%.luau$")
	if base then
		return base, "Script"
	end
	base = string.match(fileName, "^(.+)%.client%.luau$")
	if base then
		return base, "LocalScript"
	end
	base = string.match(fileName, "^(.+)%.luau$")
	if base then
		return base, "ModuleScript"
	end
	return nil, nil
end

local function mountPath(path: string, name: string, parent)
	if fs.isFile(path) then
		local base, className = classify(string.match(path, "[^/]+$"))
		if base then
			newVNode(name, className, parent, fs.readFile(path), path)
		end
		return
	end
	-- directory
	local className = "Folder"
	local source, sourcePath = nil, nil
	for _, candidate in { { "init.luau", "ModuleScript" }, { "init.server.luau", "Script" }, { "init.client.luau", "LocalScript" } } do
		local initPath = path .. "/" .. candidate[1]
		if fs.isFile(initPath) then
			className = candidate[2]
			source = fs.readFile(initPath)
			sourcePath = initPath
			break
		end
	end
	local node = newVNode(name, className, parent, source, sourcePath)
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		if not string.match(entry, "^init%.") then
			local childPath = path .. "/" .. entry
			if fs.isDir(childPath) then
				mountPath(childPath, entry, node)
			else
				local base = classify(entry)
				if base then
					mountPath(childPath, base, node)
				end
			end
		end
	end
end

local function mountProjectNode(projectNode, name: string, parent)
	if projectNode["$path"] then
		mountPath(projectNode["$path"], name, parent)
		return
	end
	local node = newVNode(name, projectNode["$className"] or "Folder", parent)
	for key, child in projectNode do
		if string.sub(key, 1, 1) ~= "$" and type(child) == "table" then
			mountProjectNode(child, key, node)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Globals and require
---------------------------------------------------------------------------------------------------

local services = {}
local moduleCache = {}
local game

local TweenInfoStub = {
	new = function(...)
		return { args = { ... } }
	end,
}

local RandomStub = {}
RandomStub.__index = RandomStub
function RandomStub.new(seed)
	return setmetatable({ seed = seed }, RandomStub)
end
function RandomStub:NextNumber(min, max)
	min = min or 0
	max = max or 1
	return min + (max - min) * math.random()
end
function RandomStub:NextInteger(min, max)
	return math.random(min, max)
end

local baseGlobals = {
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
	BrickColor = roblox.BrickColor,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	Rect = roblox.Rect,
	Font = roblox.Font,
	PhysicalProperties = roblox.PhysicalProperties,
	Ray = roblox.Ray,
	TweenInfo = TweenInfoStub,
	Random = RandomStub,
	task = task,
	tick = os.clock,
	time = os.clock,
	wait = task.wait,
	warn = function(...)
		if Harness.silenceWarnings then
			return
		end
		print("[warn]", ...)
	end,
}
Harness.globals = baseGlobals

local function harnessRequire(target)
	if not isVNode(target) then
		error("harness require expects a virtual ModuleScript, got " .. typeof(target), 2)
	end
	local cached = moduleCache[target]
	if cached then
		return cached.value
	end
	local data = internals[target]
	if data.ClassName ~= "ModuleScript" then
		error("Attempted to require non-ModuleScript " .. VNodeMethods.GetFullName(target), 2)
	end
	-- Lune copies the environment table's own keys, so globals are copied in rather than inherited.
	local env = table.clone(baseGlobals)
	env.script = target
	env.require = harnessRequire
	env.game = game
	env.workspace = services.Workspace
	local chunk = luau.load(data.source, {
		debugName = VNodeMethods.GetFullName(target),
		environment = env,
	})
	local value = chunk()
	moduleCache[target] = { value = value }
	return value
end
Harness.require = harnessRequire

-- Creates a fresh DataModel. Call before each test file that needs isolated module state.
Harness.closeCallbacks = {}

function VNodeMethods.BindToClose(_self, callback)
	table.insert(Harness.closeCallbacks, callback)
end

function Harness.reset()
	moduleCache = {}
	services = {}
	Harness.closeCallbacks = {}
	baseGlobals.Instance = roblox.Instance
	local project = serde.decode("json", fs.readFile("default.project.json"))
	game = newVNode("Game", "DataModel", nil)
	for key, child in project.tree do
		if string.sub(key, 1, 1) ~= "$" then
			mountProjectNode(child, key, game)
		end
	end
	internals[game].props.JobId = "test-job"
	internals[game].props.PlaceId = 0
	-- GetService: mounted services first, then registered mocks
	VNodeMethods.GetService = function(self, name)
		local mock = services[name]
		if mock then
			return mock
		end
		local mounted = VNodeMethods.FindFirstChild(self, name)
		if mounted then
			return mounted
		end
		error("Service not mocked in harness: " .. tostring(name), 2)
	end
	return game
end

-- Attach a non-virtual child (e.g. a proxied Lune instance) under a virtual node.
function Harness.attach(node, name: string, value)
	internals[node].external[name] = value
end

function Harness.setService(name: string, value)
	services[name] = value
end

function Harness.getGame()
	return game
end

-- Resolve "ReplicatedStorage.Shared.Logic.Economy" to a node and require it.
function Harness.requirePath(path: string)
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		node = VNodeMethods.FindFirstChild(node, part)
		if not node then
			error("No module at " .. path, 2)
		end
	end
	return harnessRequire(node)
end

function Harness.findPath(path: string)
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		node = VNodeMethods.FindFirstChild(node, part)
		if not node then
			return nil
		end
	end
	return node
end

-- Every ModuleScript in the tree, for compile checks.
function Harness.allModules()
	local result = {}
	for _, node in VNodeMethods.GetDescendants(game) do
		local cls = internals[node].ClassName
		if cls == "ModuleScript" or cls == "Script" or cls == "LocalScript" then
			table.insert(result, { node = node, className = cls, source = internals[node].source, path = internals[node].path })
		end
	end
	return result
end

-- game.JobId as seen by the modules under test.
function Harness.setJobId(jobId: string)
	internals[game].props.JobId = jobId
end

return Harness
