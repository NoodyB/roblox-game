--!strict
-- Client-side debris visuals.
--
-- * Mirrors each zone's DebrisGrid from the server snapshot + delta stream (buffers).
-- * Only zones near the camera get visuals; they are built progressively (a few hundred parts per
--   frame at most) and destroyed when far away, keeping part counts low on mobile.
-- * Each debris cell is 1-2 small anchored, non-colliding, shadowless parts whose size tracks
--   the amount left. Low Graphics mode drops the accent part.
-- * When debris near the local player disappears, a few pooled bits fly into the vacuum.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local DebrisGrid = require(Shared.Logic.DebrisGrid)
local ZoneLayout = require(Shared.Logic.ZoneLayout)
local NetCodec = require(Shared.Logic.NetCodec)
local EventLogic = require(Shared.Logic.EventLogic)
local Signal = require(Shared.Util.Signal)

local ClientState = require(script.Parent.ClientState)
local Audio = require(script.Parent.Audio)

local DebrisRenderer = {}

DebrisRenderer.WaveChanged = Signal.new() -- (zoneId, wave, golden)
DebrisRenderer.LocalCollected = Signal.new() -- (units approx)

type CellParts = { main: BasePart, extra: BasePart? }
type ZoneVisual = { folder: Folder, cells: { [number]: CellParts }, built: boolean }

local GROUND_TOP = 0.2
local ACTIVE_RANGE = GameConfig.ZoneSize / 2 + 60 -- only the zone you are in (+ neighbour near edges)
local BUILD_PER_FRAME = 90
local MAX_FLYING = 36

local grids: { [number]: DebrisGrid.DebrisGrid } = {}
local meta: { [number]: { wave: number, golden: boolean } } = {}
local visuals: { [number]: ZoneVisual } = {}
local pendingDeltas: { buffer } = {}
local root: Folder
local lowGraphics = false
local ready = false
local player = Players.LocalPlayer

local activeEvent: any = nil -- seasonal event (recolors its theme zone's debris)
local flyingPool: { BasePart } = {}
local flyingActive = 0

---------------------------------------------------------------------------------------------------
-- deterministic per-cell variation
---------------------------------------------------------------------------------------------------

local function hash(n: number): number
	local x = (n * 2654435761) % 4294967296
	x = bit32.bxor(x, bit32.rshift(x, 15))
	return (x % 1000) / 1000
end

local SHAPES = {
	leaf = { main = Vector3.new(4.6, 1.1, 4.6), extra = Vector3.new(1.8, 0.14, 1.1), mat = Enum.Material.Grass },
	acorn = { main = Vector3.new(4.2, 1.0, 4.2), extra = Vector3.new(0.9, 1.0, 0.9), mat = Enum.Material.Grass },
	cone = { main = Vector3.new(4.2, 1.0, 4.2), extra = Vector3.new(1.3, 0.9, 0.9), mat = Enum.Material.Grass }, -- cylinder: X = length, Y = Z = diameter
	shell = { main = Vector3.new(4.0, 0.8, 4.0), extra = Vector3.new(1.3, 0.6, 1.3), mat = Enum.Material.SmoothPlastic },
	snow = { main = Vector3.new(4.8, 1.6, 4.8), extra = Vector3.new(1.4, 1.2, 1.4), mat = Enum.Material.Snow },
	sprinkle = { main = Vector3.new(4.0, 0.9, 4.0), extra = Vector3.new(0.35, 1.0, 0.35), mat = Enum.Material.SmoothPlastic },
	rock = { main = Vector3.new(4.2, 1.2, 4.2), extra = Vector3.new(0.6, 0.6, 0.6), mat = Enum.Material.Slate },
	star = { main = Vector3.new(4.0, 0.8, 4.0), extra = Vector3.new(0.7, 0.7, 0.7), mat = Enum.Material.SmoothPlastic },
}

-- Debris sizes are non-uniform, and Roblox forces Ball parts to be uniform, so "ball" debris uses a
-- Block part with a Sphere SpecialMesh that stretches with the part's size.
local function newPart(parent: Instance, shape: Enum.PartType, material: Enum.Material): Part
	local p = Instance.new("Part")
	if shape == Enum.PartType.Ball then
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	else
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function styleCell(zoneId: number, index: number, parts: CellParts, amount: number)
	local grid = grids[zoneId]
	local zone = Zones[zoneId]
	local theme = zone.theme
	local shape = SHAPES[theme.debrisShape] or SHAPES.leaf
	local golden = meta[zoneId] and meta[zoneId].golden
	if amount <= 0 then
		parts.main.Transparency = 1
		if parts.extra then
			parts.extra.Transparency = 1
		end
		return
	end
	local f = 0.35 + 0.65 * (amount / GameConfig.CellMax)
	local x, z = grid:cellCenter(index)
	local h1, h2, h3 = hash(index * 3 + zoneId), hash(index * 7 + 11), hash(index * 13 + 5)
	x += (h1 - 0.5) * 1.8
	z += (h2 - 0.5) * 1.8
	local colors = if activeEvent and activeEvent.themeZone == zoneId then activeEvent.debris else theme.debris
	local color = if golden then theme.golden else colors[(index % #colors) + 1]
	local main = parts.main
	main.Size = shape.main * f
	main.CFrame = CFrame.new(x, GROUND_TOP + main.Size.Y * 0.32, z) * CFrame.Angles(0, h3 * math.pi * 2, 0)
	main.Color = color
	main.Material = if golden then Enum.Material.SmoothPlastic else shape.mat
	main.Reflectance = if golden then 0.25 else 0
	main.Transparency = 0
	local extra = parts.extra
	if extra then
		local accent = if golden then Color3.fromRGB(255, 240, 150) else colors[((index + 2) % #colors) + 1]
		extra.Size = shape.extra * math.max(f, 0.6)
		extra.Color = accent
		extra.Material = if golden or theme.debrisShape == "star" or theme.debrisShape == "rock"
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
		local ox, oz = (h2 - 0.5) * 2.2, (h1 - 0.5) * 2.2
		extra.CFrame = CFrame.new(x + ox, GROUND_TOP + main.Size.Y * 0.6 + extra.Size.Y * 0.3, z + oz)
			* CFrame.Angles(math.rad(h3 * 40 - 20), h1 * math.pi * 2, math.rad(h2 * 40 - 20))
		extra.Transparency = 0
	end
end

local function extraShapeFor(debrisShape: string): Enum.PartType
	if debrisShape == "leaf" or debrisShape == "sprinkle" then
		return Enum.PartType.Block
	end
	if debrisShape == "cone" then
		return Enum.PartType.Cylinder
	end
	return Enum.PartType.Ball
end

local function buildZone(zoneId: number)
	if visuals[zoneId] then
		return
	end
	local grid = grids[zoneId]
	if not grid then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Zone" .. zoneId
	folder.Parent = root
	local visual: ZoneVisual = { folder = folder, cells = {}, built = false }
	visuals[zoneId] = visual
	local theme = Zones[zoneId].theme
	local extraShape = extraShapeFor(theme.debrisShape)
	task.spawn(function()
		local count = 0
		for index = 0, grid:cellCount() - 1 do
			if visuals[zoneId] ~= visual then
				return -- zone was torn down while building
			end
			if not grid.mask[index] then
				local parts: CellParts = { main = newPart(folder, Enum.PartType.Ball, Enum.Material.Grass), extra = nil }
				if not lowGraphics then
					parts.extra = newPart(folder, extraShape, Enum.Material.SmoothPlastic)
				end
				visual.cells[index] = parts
				styleCell(zoneId, index, parts, grid:get(index))
				count += 1
				if count % BUILD_PER_FRAME == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
		visual.built = true
	end)
end

local function destroyZone(zoneId: number)
	local visual = visuals[zoneId]
	if visual then
		visuals[zoneId] = nil
		visual.folder:Destroy()
	end
end

local function restyleZone(zoneId: number)
	local visual = visuals[zoneId]
	local grid = grids[zoneId]
	if not visual or not grid then
		return
	end
	for index, parts in visual.cells do
		styleCell(zoneId, index, parts, grid:get(index))
	end
end

---------------------------------------------------------------------------------------------------
-- flying bits
---------------------------------------------------------------------------------------------------

local function spawnFlyer(fromX: number, fromZ: number, color: Color3, targetPart: BasePart)
	if flyingActive >= MAX_FLYING then
		return
	end
	local bit = table.remove(flyingPool)
	if not bit then
		bit = newPart(root, Enum.PartType.Block, Enum.Material.SmoothPlastic)
		bit.Size = Vector3.new(0.7, 0.12, 0.5)
	end
	flyingActive += 1
	bit.Color = color
	bit.Transparency = 0
	bit.CFrame = CFrame.new(fromX, GROUND_TOP + 0.8, fromZ) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	local target = targetPart.CFrame * CFrame.new(0.8, -0.4, -1.5)
	local tween = TweenService:Create(
		bit,
		TweenInfo.new(0.22 + math.random() * 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = target * CFrame.Angles(math.random() * 3, 0, 0), Transparency = 0.6 }
	)
	tween.Completed:Once(function()
		bit.Transparency = 1
		flyingActive -= 1
		table.insert(flyingPool, bit)
	end)
	tween:Play()
end

---------------------------------------------------------------------------------------------------
-- network
---------------------------------------------------------------------------------------------------

local function applyDelta(data: buffer)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local radius = (player:GetAttribute("Radius") :: number?) or 6
	local reach2 = (radius + 5) ^ 2
	local spawned = 0
	local localCollected = 0
	NetCodec.decodeDeltas(data, function(zoneId, index, amount)
		local grid = grids[zoneId]
		if not grid or index >= grid:cellCount() then
			return
		end
		local old = grid:get(index)
		grid:set(index, amount)
		local visual = visuals[zoneId]
		local parts = visual and visual.cells[index]
		if parts then
			styleCell(zoneId, index, parts, amount)
		end
		if amount < old and rootPart then
			local x, z = grid:cellCenter(index)
			local p = rootPart.Position
			if (p.X - x) ^ 2 + (p.Z - z) ^ 2 <= reach2 then
				localCollected += old - amount
				if spawned < 5 then
					spawned += 1
					local theme = Zones[zoneId].theme
					local golden = meta[zoneId] and meta[zoneId].golden
					spawnFlyer(x, z, if golden then theme.golden else theme.debris[(index % #theme.debris) + 1], rootPart)
				end
			end
		end
	end)
	if localCollected > 0 then
		Audio.play("Collect")
		DebrisRenderer.LocalCollected:Fire(localCollected)
	end
end

local function onWave(zoneId: number, wave: number, golden: boolean, cells: buffer)
	local grid = grids[zoneId]
	if not grid then
		return
	end
	grid:load(cells)
	meta[zoneId] = { wave = wave, golden = golden }
	restyleZone(zoneId)
	DebrisRenderer.WaveChanged:Fire(zoneId, wave, golden)
	Audio.play("Whoosh")
end

local function onReady(_state, snapshot: { [string]: any })
	for key, data in snapshot do
		local zoneId = tonumber(key)
		local grid = zoneId and grids[zoneId]
		if grid and zoneId then
			grid:load(data.cells)
			meta[zoneId] = { wave = data.wave, golden = data.golden }
		end
	end
	ready = true
	DebrisRenderer.refreshEvent()
	for _, delta in pendingDeltas do
		applyDelta(delta)
	end
	table.clear(pendingDeltas)
	for zoneId in visuals do
		restyleZone(zoneId)
	end
end

---------------------------------------------------------------------------------------------------
-- public
---------------------------------------------------------------------------------------------------

-- Re-checks the seasonal event and restyles the affected zone if it changed.
function DebrisRenderer.refreshEvent()
	local event = EventLogic.active(Workspace:GetServerTimeNow())
	if event ~= activeEvent then
		local previous = activeEvent
		activeEvent = event
		for _, e in { previous, event } do
			if e then
				restyleZone(e.themeZone)
			end
		end
	end
end

function DebrisRenderer.cleanFraction(zoneId: number): number
	local grid = grids[zoneId]
	return if grid then grid:cleanFraction() else 0
end

function DebrisRenderer.isGolden(zoneId: number): boolean
	return meta[zoneId] ~= nil and meta[zoneId].golden
end

function DebrisRenderer.nearestDebris(x: number, z: number, zoneId: number): Vector3?
	local grid = grids[zoneId]
	if not grid then
		return nil
	end
	local best, bestD = nil, math.huge
	for index = 0, grid:cellCount() - 1, 3 do
		if grid:get(index) > 0 then
			local cx, cz = grid:cellCenter(index)
			local d = (cx - x) ^ 2 + (cz - z) ^ 2
			if d < bestD then
				best, bestD = Vector3.new(cx, GROUND_TOP + 0.5, cz), d
			end
		end
	end
	return best
end

function DebrisRenderer.setLowGraphics(value: boolean)
	if value == lowGraphics then
		return
	end
	lowGraphics = value
	for zoneId in table.clone(visuals) do
		destroyZone(zoneId)
	end
end

function DebrisRenderer:Init()
	root = Instance.new("Folder")
	root.Name = "DebrisVisuals"
	root.Parent = Workspace

	for zoneId = 1, #Zones do
		local originX, originZ, cols, rows = ZoneLayout.debrisArea(zoneId)
		grids[zoneId] = DebrisGrid.new({
			cols = cols,
			rows = rows,
			cellSize = GameConfig.CellSize,
			originX = originX,
			originZ = originZ,
			cellMax = GameConfig.CellMax,
			mask = ZoneLayout.mask(zoneId),
		})
		meta[zoneId] = { wave = 1, golden = false }
	end

	ClientState.remote("DebrisDelta").OnClientEvent:Connect(function(data: buffer)
		if ready then
			applyDelta(data)
		else
			table.insert(pendingDeltas, data)
		end
	end)
	ClientState.remote("ZoneWave").OnClientEvent:Connect(onWave)
	ClientState.Ready:Connect(onReady)
	ClientState.Changed:Connect(function(state)
		if state.settings then
			DebrisRenderer.setLowGraphics(state.settings.lowGraphics == true)
		end
	end)
end

-- One streaming pass: build visuals for zones near the focus point, drop far ones.
local function streamStep()
	if not ready then
		return
	end
	local focus: Vector3
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		focus = rootPart.Position
	else
		local camera = Workspace.CurrentCamera
		focus = if camera then camera.Focus.Position else Vector3.zero
	end
	for zoneId = 1, #Zones do
		local cx = ZoneLayout.center(zoneId)
		local near = math.abs(focus.X - cx) <= ACTIVE_RANGE
		if near and not visuals[zoneId] then
			buildZone(zoneId)
		elseif not near and visuals[zoneId] then
			destroyZone(zoneId)
		end
	end
end

function DebrisRenderer:Start()
	-- stream zone visuals in/out around the camera focus; re-check seasonal events every ~30s
	task.spawn(function()
		local ticks = 0
		while true do
			streamStep()
			ticks += 1
			if ticks % 60 == 0 then
				DebrisRenderer.refreshEvent()
			end
			task.wait(0.5)
		end
	end)
end

DebrisRenderer._streamStep = streamStep
DebrisRenderer._buildZone = buildZone

return DebrisRenderer
