--!nocheck
-- Validates a built place file (the actual artifact you open in Studio).
--   lune run tools/validate_place.luau build/SweepSquad.rbxl

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build/SweepSquad.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local failures = {}

local function check(condition, message)
	if not condition then
		table.insert(failures, message)
	end
end

local function find(root, dotted)
	local node = root
	for name in string.gmatch(dotted, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")

-- Required structure
local expected = {
	{ ServerScriptService, "Server.Main", "Script" },
	{ StarterPlayer, "StarterPlayerScripts.Client.Main", "LocalScript" },
	{ ReplicatedFirst, "LoadingScreen", "LocalScript" },
	{ ReplicatedStorage, "Shared.Config.GameConfig", "ModuleScript" },
	{ ReplicatedStorage, "Shared.Logic.DebrisGrid", "ModuleScript" },
	{ ReplicatedStorage, "Shared.World.MapBuilder", "ModuleScript" },
	{ ReplicatedStorage, "Shared.Net.Remotes", "ModuleScript" },
}
for _, service in { "Net", "DataService", "PassService", "WorldService", "PlayerService", "CritterService", "DebrisService", "QuestService", "ShopService", "MonetizationService", "LeaderboardService" } do
	table.insert(expected, { ServerScriptService, "Server.Services." .. service, "ModuleScript" })
end
for _, entry in expected do
	local node = find(entry[1], entry[2])
	check(node ~= nil, "missing " .. entry[1].Name .. "." .. entry[2])
	if node then
		check(node.ClassName == entry[3], entry[2] .. " should be a " .. entry[3] .. " (is " .. node.ClassName .. ")")
	end
end

-- Every script compiles and nothing client-side leaked into server-only locations (and vice versa)
local counts = { Script = 0, LocalScript = 0, ModuleScript = 0 }
local lines = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		counts[d.ClassName] += 1
		local source = d.Source
		check(#source > 0, d:GetFullName() .. " is empty")
		local _, n = string.gsub(source, "\n", "")
		lines += n
		local ok, err = pcall(luau.compile, source)
		check(ok, d:GetFullName() .. " does not compile: " .. tostring(err))
		if d.ClassName == "LocalScript" then
			local underServer = d:FindFirstAncestorOfClass("ServerScriptService")
			check(underServer == nil, "LocalScript inside ServerScriptService: " .. d:GetFullName())
		end
	end
end
check(counts.Script == 1, "expected exactly 1 server Script, found " .. counts.Script)
check(counts.LocalScript == 2, "expected 2 LocalScripts, found " .. counts.LocalScript)

-- Lighting setup
check(Lighting.Technology == roblox.Enum.Technology.ShadowMap, "Lighting.Technology should be ShadowMap")
check(Lighting:FindFirstChildOfClass("Atmosphere") ~= nil, "Lighting is missing an Atmosphere")
check(Lighting:FindFirstChildOfClass("ColorCorrectionEffect") ~= nil, "Lighting is missing ColorCorrection")

print(string.format("Place: %s", path))
print(string.format("Scripts: %d server, %d client, %d modules (%d lines of Luau)", counts.Script, counts.LocalScript, counts.ModuleScript, lines))
if #failures > 0 then
	for _, f in failures do
		print("FAIL: " .. f)
	end
	process.exit(1)
end
print("Place file OK")
