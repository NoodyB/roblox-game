--!strict
-- Renders every player's equipped critters (from the replicated "Equipped" attribute) as little
-- companions that hop along behind them. Entirely client-side: zero server or physics cost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Stats = require(Shared.Logic.Stats)
local CritterModels = require(Shared.World.CritterModels)

local ClientState = require(script.Parent.ClientState)

local CritterFollowers = {}

type Follower = { model: Model, current: CFrame, phase: number }
type Entry = { key: string, followers: { Follower } }

local SLOT_OFFSETS = {
	Vector3.new(-3.2, 0, 3.6),
	Vector3.new(3.2, 0, 3.6),
	Vector3.new(0, 0, 6),
	Vector3.new(-4, 0, 7.5),
	Vector3.new(4, 0, 7.5),
	Vector3.new(0, 0, 9.5),
	Vector3.new(-2.5, 0, 11),
	Vector3.new(2.5, 0, 11),
}
local UPDATE_DISTANCE = 160

local entries: { [Player]: Entry } = {}
local folder: Folder
local showOthers = true
local localPlayer = Players.LocalPlayer

local function clear(target: Player)
	local entry = entries[target]
	if entry then
		for _, f in entry.followers do
			f.model:Destroy()
		end
		entries[target] = nil
	end
end

local function rebuild(target: Player)
	local raw = target:GetAttribute("Equipped")
	local key = if type(raw) == "string" then raw else ""
	if target ~= localPlayer and not showOthers then
		key = ""
	end
	local existing = entries[target]
	if existing and existing.key == key then
		return
	end
	clear(target)
	local entry: Entry = { key = key, followers = {} }
	entries[target] = entry
	if key == "" then
		return
	end
	local index = 0
	for part in string.gmatch(key, "[^,]+") do
		index += 1
		if index > #SLOT_OFFSETS then
			break
		end
		local id, golden = Stats.parseEquipped(part)
		local model = CritterModels.build(id, golden, folder, CFrame.new(0, -500, 0), 0.8)
		if model then
			table.insert(entry.followers, { model = model, current = CFrame.new(0, -500, 0), phase = index * 1.7 })
		end
	end
end

local function watch(target: Player)
	target:GetAttributeChangedSignal("Equipped"):Connect(function()
		rebuild(target)
	end)
	rebuild(target)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 7)
	for target, entry in entries do
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and #entry.followers > 0 then
			local rootPos = root.Position
			if (rootPos - cameraPos).Magnitude <= UPDATE_DISTANCE then
				local look = root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.01 then
					flat = Vector3.new(0, 0, -1)
				end
				local basis = CFrame.lookAt(Vector3.zero, flat.Unit)
				local moving = root.AssemblyLinearVelocity.Magnitude > 2
				local groundY = rootPos.Y - 3
				for i, follower in entry.followers do
					local offset = basis:VectorToWorldSpace(SLOT_OFFSETS[i])
					local hop = if moving
						then math.abs(math.sin(now * 9 + follower.phase)) * 0.9
						else math.sin(now * 2 + follower.phase) * 0.12 + 0.12
					local target = CFrame.lookAt(
						Vector3.new(rootPos.X + offset.X, groundY + hop, rootPos.Z + offset.Z),
						Vector3.new(rootPos.X + offset.X + flat.X, groundY + hop, rootPos.Z + offset.Z + flat.Z)
					)
					if (follower.current.Position - target.Position).Magnitude > 40 then
						follower.current = target -- snap after teleports
					else
						follower.current = follower.current:Lerp(target, alpha)
					end
					follower.model:PivotTo(follower.current)
				end
			end
		end
	end
end

function CritterFollowers:Init()
	folder = Instance.new("Folder")
	folder.Name = "CritterFollowers"
	folder.Parent = Workspace
	ClientState.Changed:Connect(function(state)
		local value = state.settings and state.settings.showCritters ~= false
		if value ~= showOthers then
			showOthers = value
			for _, target in Players:GetPlayers() do
				local entry = entries[target]
				if entry then
					entry.key = "\0" -- force rebuild
				end
				rebuild(target)
			end
		end
	end)
end

function CritterFollowers:Start()
	for _, target in Players:GetPlayers() do
		watch(target)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(step)
end

CritterFollowers._rebuild = rebuild

return CritterFollowers
