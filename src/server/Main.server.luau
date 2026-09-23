--!strict
-- Server entry point. Services are initialized in dependency order, then started.
-- Init() wires state and remotes (no yielding); Start() launches loops.

local Services = script.Parent:WaitForChild("Services")

local ORDER = {
	"Net",
	"DataService",
	"PassService",
	"WorldService",
	"PlayerService",
	"CritterService",
	"DebrisService",
	"QuestService",
	"ShopService",
	"MonetizationService",
	"LeaderboardService",
}

local loaded = {}
for _, name in ORDER do
	local ok, service = pcall(require, Services:WaitForChild(name))
	if not ok then
		error(string.format("[Main] failed to load %s: %s", name, tostring(service)))
	end
	loaded[name] = service
end

for _, name in ORDER do
	local service = loaded[name]
	if type(service.Init) == "function" then
		local startedAt = os.clock()
		service:Init()
		local elapsed = os.clock() - startedAt
		if elapsed > 0.5 then
			warn(string.format("[Main] %s:Init took %.2fs", name, elapsed))
		end
	end
end

for _, name in ORDER do
	local service = loaded[name]
	if type(service.Start) == "function" then
		task.spawn(function()
			service:Start()
		end)
	end
end

print("[Sweep Squad] server ready")
