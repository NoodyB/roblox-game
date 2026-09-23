--!strict
-- Procedural critter models (about 8-14 parts each) built from a species' archetype, colors and
-- features. Used client-side for followers, the Critter Book and find celebrations.
-- Models face -Z (their LookVector) and stand on the base CFrame.

local Shared = script.Parent.Parent
local Critters = require(Shared.Config.Critters)
local Build = require(script.Parent.Build)

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local CritterModels = {}

local GOLD = rgb(255, 204, 64)
local GOLD_ACCENT = rgb(255, 240, 170)
local EYE = rgb(30, 24, 30)

type Opts = { material: Enum.Material }

local function eyes(m: Model, base: CFrame, y: number, z: number, spread: number, size: number)
	for _, side in { -1, 1 } do
		Build.ball(m, V(size, size, size * 0.6), base * CF(side * spread, y, z), EYE, { shadow = false, name = "Eye" })
		Build.ball(m, V(size * 0.35, size * 0.35, size * 0.2), base * CF(side * spread + size * 0.15, y + size * 0.18, z - size * 0.25), rgb(255, 255, 255), { shadow = false, name = "Shine" })
	end
end

local function quad(m: Model, c: Critters.Critter, base: CFrame, body: Color3, accent: Color3, o: Opts)
	Build.ball(m, V(2.1, 1.8, 2.5), base * CF(0, 1.3, 0.2), body, { material = o.material, name = "Body" })
	Build.ball(m, V(1.4, 1.1, 1.2), base * CF(0, 1.2, -0.75), accent, { material = o.material, name = "Belly" })
	Build.ball(m, V(1.8, 1.7, 1.7), base * CF(0, 2.35, -1.05), body, { material = o.material, name = "Head" })
	Build.ball(m, V(0.9, 0.7, 0.6), base * CF(0, 2.1, -1.85), accent, { material = o.material, name = "Snout" })
	Build.ball(m, V(0.3, 0.25, 0.2), base * CF(0, 2.25, -2.15), EYE, { shadow = false, name = "Nose" })
	eyes(m, base, 2.6, -1.8, 0.45, 0.38)
	for _, x in { -0.6, 0.6 } do
		for _, z in { -0.6, 0.9 } do
			Build.ball(m, V(0.55, 0.7, 0.55), base * CF(x, 0.35, z), Build.shade(body, 0.85), { material = o.material, name = "Leg" })
		end
	end
	local ears = c.ears or "round"
	for _, side in { -1, 1 } do
		if ears == "pointy" then
			Build.wedge(m, V(0.25, 0.9, 0.6), base * CF(side * 0.55, 3.35, -1) * CFrame.Angles(0, 0, rad(side * -12)), body, { material = o.material, name = "Ear" })
		elseif ears == "long" then
			Build.ball(m, V(0.45, 1.6, 0.35), base * CF(side * 0.4, 3.7, -0.9) * CFrame.Angles(0, 0, rad(side * -10)), body, { material = o.material, name = "Ear" })
			Build.ball(m, V(0.25, 1.1, 0.1), base * CF(side * 0.4, 3.7, -1.05) * CFrame.Angles(0, 0, rad(side * -10)), accent, { shadow = false, name = "EarInner" })
		else
			Build.ball(m, V(0.65, 0.65, 0.35), base * CF(side * 0.65, 3.1, -1), body, { material = o.material, name = "Ear" })
		end
	end
	local tail = c.tail or "puff"
	if tail == "bushy" then
		Build.ball(m, V(1.1, 1.8, 1.1), base * CF(0, 2.2, 1.6) * CFrame.Angles(rad(-25), 0, 0), body, { material = o.material, name = "Tail" })
		Build.ball(m, V(0.8, 0.7, 0.8), base * CF(0, 3, 1.95), accent, { material = o.material, name = "TailTip" })
	elseif tail == "thin" then
		Build.block(m, V(0.25, 0.25, 1.6), base * CF(0, 1.7, 1.9) * CFrame.Angles(rad(30), 0, 0), body, { material = o.material, name = "Tail" })
	else
		Build.ball(m, V(0.7, 0.7, 0.7), base * CF(0, 1.5, 1.5), accent, { material = o.material, name = "Tail" })
	end
end

local function bird(m: Model, c: Critters.Critter, base: CFrame, body: Color3, accent: Color3, o: Opts)
	Build.ball(m, V(2, 2.3, 2), base * CF(0, 1.5, 0), body, { material = o.material, name = "Body" })
	Build.ball(m, V(1.4, 1.5, 0.8), base * CF(0, 1.3, -0.65), accent, { material = o.material, name = "Belly" })
	eyes(m, base, 2.1, -0.85, 0.42, 0.4)
	Build.wedge(m, V(0.45, 0.35, 0.7), base * CF(0, 1.75, -1.2), rgb(255, 180, 50), { shadow = false, name = "Beak" })
	for _, side in { -1, 1 } do
		Build.ball(m, V(0.5, 1.4, 1.2), base * CF(side * 1, 1.4, 0.1) * CFrame.Angles(0, 0, rad(side * 15)), Build.shade(body, 0.85), { material = o.material, name = "Wing" })
		Build.ball(m, V(0.5, 0.25, 0.7), base * CF(side * 0.45, 0.2, -0.2), rgb(255, 180, 50), { shadow = false, name = "Foot" })
		if c.ears == "tufts" then
			Build.wedge(m, V(0.2, 0.7, 0.5), base * CF(side * 0.55, 2.85, -0.2), body, { material = o.material, name = "Tuft" })
		end
	end
end

local function blob(m: Model, c: Critters.Critter, base: CFrame, body: Color3, accent: Color3, o: Opts)
	Build.ball(m, V(2.5, 1.9, 2.4), base * CF(0, 1, 0), body, { material = o.material, name = "Body" })
	Build.ball(m, V(1.6, 0.9, 1), base * CF(0, 0.75, -0.8), accent, { material = o.material, name = "Belly" })
	eyes(m, base, 1.45, -1.05, 0.5, 0.42)
	if c.extra == "spikes" then
		for i = 0, 5 do
			local a = rad(-60 + i * 24)
			Build.wedge(m, V(0.35, 0.7, 0.5), base * CF(math.sin(a) * 0.9, 1.75, 0.3 + math.cos(a) * 0.3) * CFrame.Angles(rad(-30), a, 0), Build.shade(body, 0.75), { material = o.material, name = "Spike" })
		end
	elseif c.extra == "stem" then
		Build.cylinder(m, 0.6, 0.3, base * CF(0, 2.1, 0), rgb(100, 150, 60), { name = "Stem" })
	end
	if c.ears == "round" then
		for _, side in { -1, 1 } do
			Build.ball(m, V(0.6, 0.6, 0.35), base * CF(side * 0.75, 1.95, -0.2), body, { material = o.material, name = "Ear" })
		end
	end
end

local function sea(m: Model, c: Critters.Critter, base: CFrame, body: Color3, accent: Color3, o: Opts)
	Build.ball(m, V(2.2, 1.2, 2.6), base * CF(0, 0.8, 0), body, { material = o.material, name = "Body" })
	Build.ball(m, V(1.5, 1.1, 1.3), base * CF(0, 1.1, -1.3), body, { material = o.material, name = "Head" })
	eyes(m, base, 1.45, -1.9, 0.38, 0.34)
	local extra = c.extra
	if extra == "shell" then
		Build.ball(m, V(2.4, 1.5, 2.4), base * CF(0, 1.3, 0.3), accent, { material = o.material, name = "Shell" })
	elseif extra == "claws" then
		for _, side in { -1, 1 } do
			Build.ball(m, V(0.9, 0.7, 0.9), base * CF(side * 1.3, 1, -1.3), body, { material = o.material, name = "Claw" })
			Build.ball(m, V(0.3, 0.9, 0.3), base * CF(side * 0.35, 1.9, -1.4), body, { material = o.material, name = "Stalk" })
		end
	elseif extra == "fin" then
		Build.wedge(m, V(0.25, 1, 1.2), base * CF(0, 1.7, 0.2), accent, { material = o.material, name = "Fin" })
		Build.ball(m, V(1.6, 0.3, 0.8), base * CF(0, 0.9, 1.6), accent, { material = o.material, name = "Fluke" })
	elseif extra == "tail" then
		Build.ball(m, V(0.6, 0.5, 2), base * CF(0, 0.6, 1.9), body, { material = o.material, name = "Tail" })
		for i = 0, 2 do
			Build.wedge(m, V(0.2, 0.45, 0.5), base * CF(0, 1.4, 0.8 - i * 0.7), accent, { material = o.material, name = "Crest" })
		end
	elseif extra == "gills" then
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				Build.block(m, V(0.15, 0.7, 0.15), base * CF(side * 0.8, 1.5 + i * 0.1, -1.1 + i * 0.25) * CFrame.Angles(0, 0, rad(side * (-35 + i * 20))), accent, { material = o.material, name = "Gill" })
			end
		end
	end
	for _, side in { -1, 1 } do
		Build.ball(m, V(0.5, 0.3, 0.7), base * CF(side * 1.05, 0.25, -0.4), Build.shade(body, 0.85), { material = o.material, name = "Flipper" })
	end
end

local ARCHETYPES = { quad = quad, bird = bird, blob = blob, sea = sea }

-- Builds a critter standing on `base`. `scale` multiplies the ~2.5 stud default size.
function CritterModels.build(critterId: string, golden: boolean, parent: Instance?, base: CFrame?, scale: number?): Model?
	local c = Critters.ById[critterId]
	if not c then
		return nil
	end
	local s = scale or 1
	local origin = base or CFrame.new()
	local m = Build.model(critterId, nil)
	local body = if golden then GOLD else c.body
	local accent = if golden then GOLD_ACCENT else c.accent
	local material = if golden then Enum.Material.Foil else Enum.Material.SmoothPlastic
	local builder = ARCHETYPES[c.archetype] or quad
	-- build at unit scale around the origin, then scale positions/sizes
	builder(m, c, CFrame.new(), body, accent, { material = material })

	-- horns / glow features common to all archetypes
	if c.extra == "horn" then
		Build.wedge(m, V(0.3, 1, 0.4), CF(0, 3.5, -1.5), GOLD, { material = Enum.Material.Foil, name = "Horn" })
	elseif c.extra == "horns" then
		for _, side in { -1, 1 } do
			Build.wedge(m, V(0.25, 0.7, 0.35), CF(side * 0.5, 3.4, -1.2), rgb(200, 220, 240), { name = "Horn" })
		end
	end
	if c.extra == "glow" or golden then
		local core = m:FindFirstChild("Body") :: BasePart?
		if core then
			local light = Instance.new("PointLight")
			light.Range = 8
			light.Brightness = if golden then 1.2 else 0.8
			light.Color = if golden then GOLD else accent
			light.Shadows = false
			light.Parent = core
		end
	end

	local root = Build.block(m, V(0.2, 0.2, 0.2), CFrame.new(), rgb(255, 255, 255), { transparency = 1, shadow = false, name = "Root" })
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local offset = d.CFrame
			d.Size = d.Size * s
			d.CFrame = origin * (CFrame.new(offset.Position * s) * offset.Rotation)
			d.CastShadow = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m.PrimaryPart = root
	m:SetAttribute("CritterId", critterId)
	m:SetAttribute("Golden", golden)
	if parent then
		m.Parent = parent
	end
	return m
end

return CritterModels
