--!strict
-- Procedural prop library. Every prop is assembled from primitive parts in a cozy, low-poly style.
-- Props.build(kind, parent, baseCFrame, scale, theme) builds the prop standing on baseCFrame.

local Build = require(script.Parent.Build)

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local Props = {}

type Builder = (m: Model, base: CFrame, s: number, theme: any) -> ()

local TRUNK = rgb(120, 84, 56)
local TRUNK_DARK = rgb(96, 66, 44)
local AUTUMN = { rgb(236, 120, 40), rgb(222, 76, 44), rgb(246, 180, 60), rgb(200, 96, 40) }
local PINE = rgb(52, 110, 68)
local ROCK = rgb(150, 146, 140)

local function pick<T>(list: { T }, seed: number): T
	return list[(math.floor(seed) % #list) + 1]
end

local builders: { [string]: Builder } = {}

builders.autumnTree = function(m, base, s, _theme)
	local seed = base.Position.X * 3 + base.Position.Z
	Build.cylinder(m, 7 * s, 1.6 * s, base * CF(0, 3.5 * s, 0), TRUNK, { material = Enum.Material.Wood })
	local color = pick(AUTUMN, seed)
	Build.ball(m, V(8, 7, 8) * s, base * CF(0, 8.5 * s, 0), color, { material = Enum.Material.Grass })
	Build.ball(m, V(5.5, 5, 5.5) * s, base * CF(2.2 * s, 7.4 * s, 1.4 * s), Build.shade(color, 1.12), { material = Enum.Material.Grass })
	Build.ball(m, V(5, 4.5, 5) * s, base * CF(-2.4 * s, 7.8 * s, -1.2 * s), Build.shade(color, 0.9), { material = Enum.Material.Grass })
end

builders.bush = function(m, base, s, theme)
	local color = if theme and theme.border then Build.shade(theme.border, 0.9) else rgb(90, 140, 70)
	Build.ball(m, V(4.5, 3.2, 4) * s, base * CF(0, 1.3 * s, 0), color, { material = Enum.Material.Grass })
	Build.ball(m, V(3, 2.4, 3) * s, base * CF(1.6 * s, 1 * s, 0.6 * s), Build.shade(color, 1.1), { material = Enum.Material.Grass })
	Build.ball(m, V(0.6, 0.6, 0.6) * s, base * CF(0.8 * s, 2.6 * s, -1.2 * s), rgb(230, 60, 70), { shadow = false })
end

builders.bench = function(m, base, s)
	local wood = rgb(176, 120, 72)
	Build.block(m, V(5, 0.4, 1.6) * s, base * CF(0, 1.6 * s, 0), wood, { material = Enum.Material.Wood, collide = true })
	Build.block(m, V(5, 1.4, 0.3) * s, base * CF(0, 2.6 * s, 0.8 * s), wood, { material = Enum.Material.Wood })
	for _, x in { -2.1, 2.1 } do
		Build.block(m, V(0.35, 1.6, 1.4) * s, base * CF(x * s, 0.8 * s, 0), rgb(60, 60, 66), { material = Enum.Material.Metal })
	end
end

builders.lamp = function(m, base, s, _theme)
	Build.cylinder(m, 9 * s, 0.5 * s, base * CF(0, 4.5 * s, 0), rgb(50, 50, 58), { material = Enum.Material.Metal, collide = true })
	local bulb = Build.ball(m, V(1.6, 1.6, 1.6) * s, base * CF(0, 9.4 * s, 0), rgb(255, 230, 170), { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.2
	light.Color = rgb(255, 214, 160)
	light.Shadows = false
	light.Parent = bulb
	Build.cylinder(m, 0.4 * s, 2.2 * s, base * CF(0, 10.3 * s, 0), rgb(50, 50, 58), { material = Enum.Material.Metal })
end

builders.rock = function(m, base, s, theme)
	local color = if theme and theme.props == "beach" then rgb(196, 180, 150) else ROCK
	Build.ball(m, V(4.5, 2.6, 3.6) * s, base * CF(0, 0.9 * s, 0), color, { material = Enum.Material.Slate, collide = true })
	Build.ball(m, V(2.4, 1.8, 2.2) * s, base * CF(1.8 * s, 0.6 * s, 1 * s), Build.shade(color, 1.1), { material = Enum.Material.Slate })
end

builders.pumpkin = function(m, base, s)
	local orange = rgb(240, 130, 30)
	for i = 0, 3 do
		local angle = rad(i * 45)
		Build.ball(m, V(4.4, 3.2, 2.2) * s, base * CF(0, 1.6 * s, 0) * CFrame.Angles(0, angle, 0), if i % 2 == 0 then orange else Build.shade(orange, 0.92), { material = Enum.Material.SmoothPlastic, collide = i == 0 })
	end
	Build.cylinder(m, 1.2 * s, 0.5 * s, base * CF(0, 3.5 * s, 0), rgb(90, 130, 50))
	Build.ball(m, V(1.6, 0.4, 1) * s, base * CF(0.7 * s, 3.4 * s, 0) * CFrame.Angles(0, 0, rad(-20)), rgb(100, 160, 60), { shadow = false })
end

builders.jackOLantern = function(m, base, s)
	builders.pumpkin(m, base, s)
	local glow = rgb(255, 170, 40)
	for _, x in { -0.7, 0.7 } do
		Build.wedge(m, V(0.6, 0.6, 0.2) * s, base * CF(x * s, 2.1 * s, -2.1 * s), glow, { material = Enum.Material.Neon, shadow = false })
	end
	local mouth = Build.block(m, V(1.6, 0.35, 0.2) * s, base * CF(0, 1.2 * s, -2.15 * s), glow, { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 1.5
	light.Color = glow
	light.Shadows = false
	light.Parent = mouth
end

builders.haybale = function(m, base, s)
	local hay = rgb(230, 196, 100)
	Build.cylinderX(m, 5 * s, 3.4 * s, base * CF(0, 1.7 * s, 0), hay, { material = Enum.Material.Fabric, collide = true })
	for _, x in { -1.4, 1.4 } do
		Build.cylinderX(m, 0.2 * s, 3.5 * s, base * CF(x * s, 1.7 * s, 0), rgb(170, 120, 60))
	end
end

builders.scarecrow = function(m, base, s)
	local wood = TRUNK
	Build.block(m, V(0.5, 7, 0.5) * s, base * CF(0, 3.5 * s, 0), wood, { material = Enum.Material.Wood, collide = true })
	Build.block(m, V(5, 0.4, 0.4) * s, base * CF(0, 5 * s, 0), wood, { material = Enum.Material.Wood })
	Build.block(m, V(2.6, 2.4, 1.2) * s, base * CF(0, 4.6 * s, 0), rgb(90, 140, 200), { material = Enum.Material.Fabric })
	Build.ball(m, V(1.8, 1.8, 1.8) * s, base * CF(0, 6.8 * s, 0), rgb(236, 200, 120), { material = Enum.Material.Fabric })
	Build.cylinder(m, 0.2 * s, 3.2 * s, base * CF(0, 7.6 * s, 0), rgb(170, 120, 60), { material = Enum.Material.Fabric })
	Build.cylinder(m, 1 * s, 1.4 * s, base * CF(0, 8.1 * s, 0), rgb(170, 120, 60), { material = Enum.Material.Fabric })
end

builders.pine = function(m, base, s, theme)
	local color = if theme and theme.props == "snow" then rgb(60, 110, 90) else PINE
	Build.cylinder(m, 4 * s, 1.2 * s, base * CF(0, 2 * s, 0), TRUNK_DARK, { material = Enum.Material.Wood, collide = true })
	local layers = { { 7, 4.5, 3.5 }, { 5.5, 4, 6.2 }, { 4, 3.4, 8.6 }, { 2.4, 2.6, 10.6 } }
	for i, layer in layers do
		local width, height, y = layer[1], layer[2], layer[3]
		Build.cylinder(m, height * s, width * s, base * CF(0, y * s, 0), Build.shade(color, 0.9 + i * 0.06), { material = Enum.Material.Grass })
		if theme and theme.props == "snow" then
			Build.cylinder(m, 0.5 * s, (width - 0.6) * s, base * CF(0, (y + height / 2) * s, 0), rgb(245, 250, 255), { material = Enum.Material.Snow, shadow = false })
		end
	end
end

builders.snowPine = function(m, base, s, _theme)
	builders.pine(m, base, s, { props = "snow" })
end

builders.stump = function(m, base, s)
	Build.cylinder(m, 2 * s, 3.4 * s, base * CF(0, 1 * s, 0), TRUNK, { material = Enum.Material.Wood, collide = true })
	Build.cylinder(m, 0.1 * s, 2.8 * s, base * CF(0, 2.02 * s, 0), rgb(220, 180, 120), { material = Enum.Material.Wood, shadow = false })
	Build.ball(m, V(1, 0.5, 1) * s, base * CF(1.2 * s, 2.1 * s, 0.4 * s), rgb(220, 60, 60), { shadow = false })
end

builders.mushroom = function(m, base, s)
	Build.cylinder(m, 2.2 * s, 1 * s, base * CF(0, 1.1 * s, 0), rgb(245, 235, 215), { collide = true })
	Build.ball(m, V(3.6, 1.8, 3.6) * s, base * CF(0, 2.4 * s, 0), rgb(220, 60, 60))
	for i = 0, 3 do
		local a = rad(i * 90 + 30)
		Build.ball(m, V(0.6, 0.3, 0.6) * s, base * CF(math.cos(a) * 1.1 * s, 3.1 * s, math.sin(a) * 1.1 * s), rgb(255, 250, 240), { shadow = false })
	end
end

builders.palm = function(m, base, s)
	local trunk = rgb(170, 130, 80)
	for i = 0, 5 do
		Build.cylinder(m, 1.6 * s, (1.3 - i * 0.07) * s, base * CF(i * 0.25 * s, (0.8 + i * 1.5) * s, 0) * CFrame.Angles(0, 0, rad(-4)), if i % 2 == 0 then trunk else Build.shade(trunk, 0.88), { material = Enum.Material.Wood, collide = i == 0 })
	end
	local top = base * CF(1.5 * s, 9.3 * s, 0)
	for i = 0, 5 do
		local a = rad(i * 60)
		Build.block(m, V(5.5, 0.3, 1.4) * s, top * CFrame.Angles(0, a, rad(-20)) * CF(2.6 * s, 0, 0), rgb(70, 170, 80), { material = Enum.Material.Grass })
	end
	Build.ball(m, V(0.9, 0.9, 0.9) * s, top * CF(0, -0.6 * s, 0.6 * s), rgb(110, 80, 50))
end

builders.umbrella = function(m, base, s)
	Build.cylinder(m, 6 * s, 0.3 * s, base * CF(0, 3 * s, 0), rgb(240, 240, 240), { collide = true })
	-- striped dome canopy: a flattened sphere with a contrasting band and top knob
	Build.ball(m, V(6, 1.8, 6) * s, base * CF(0, 6.1 * s, 0), rgb(240, 80, 80))
	Build.cylinder(m, 0.5 * s, 5.2 * s, base * CF(0, 6.2 * s, 0), rgb(255, 255, 255), { shadow = false })
	Build.ball(m, V(0.6, 0.6, 0.6) * s, base * CF(0, 7.05 * s, 0), rgb(255, 255, 255), { shadow = false })
	Build.block(m, V(3, 0.3, 5) * s, base * CF(2.5 * s, 0.2 * s, 0), rgb(80, 180, 230), { material = Enum.Material.Fabric, shadow = false })
end

builders.sandcastle = function(m, base, s)
	local sand = rgb(226, 200, 140)
	Build.block(m, V(4, 1.6, 4) * s, base * CF(0, 0.8 * s, 0), sand, { material = Enum.Material.Sand, collide = true })
	for _, p in { V(-1.6, 0, -1.6), V(1.6, 0, -1.6), V(-1.6, 0, 1.6), V(1.6, 0, 1.6) } do
		Build.cylinder(m, 2.6 * s, 1.2 * s, base * CF(p.X * s, 1.3 * s, p.Z * s), sand, { material = Enum.Material.Sand })
	end
	Build.cylinder(m, 3.4 * s, 1.8 * s, base * CF(0, 2.8 * s, 0), sand, { material = Enum.Material.Sand })
	Build.block(m, V(0.1, 0.8, 1.2) * s, base * CF(0.2 * s, 5 * s, 0), rgb(240, 80, 80), { shadow = false })
end

builders.snowman = function(m, base, s)
	local snow = rgb(248, 250, 255)
	Build.ball(m, V(3.6, 3.6, 3.6) * s, base * CF(0, 1.7 * s, 0), snow, { material = Enum.Material.Snow, collide = true })
	Build.ball(m, V(2.7, 2.7, 2.7) * s, base * CF(0, 4.3 * s, 0), snow, { material = Enum.Material.Snow })
	Build.ball(m, V(2, 2, 2) * s, base * CF(0, 6.2 * s, 0), snow, { material = Enum.Material.Snow })
	Build.wedge(m, V(0.3, 0.3, 1.2) * s, base * CF(0, 6.2 * s, -1.4 * s), rgb(255, 140, 40), { shadow = false })
	Build.cylinder(m, 1.4 * s, 1.4 * s, base * CF(0, 7.6 * s, 0), rgb(40, 40, 50))
	Build.cylinder(m, 0.2 * s, 2.2 * s, base * CF(0, 7 * s, 0), rgb(40, 40, 50))
	Build.block(m, V(2.4, 0.5, 0.6) * s, base * CF(0, 5.3 * s, -0.4 * s), rgb(220, 50, 60), { material = Enum.Material.Fabric })
end

builders.iceRock = function(m, base, s)
	local ice = rgb(170, 220, 250)
	Build.ball(m, V(4, 2.6, 3.4) * s, base * CF(0, 1 * s, 0), ice, { material = Enum.Material.Ice, collide = true, transparency = 0.1 })
	Build.wedge(m, V(1.4, 3.2, 1.4) * s, base * CF(1.2 * s, 2.2 * s, 0), Build.shade(ice, 1.1), { material = Enum.Material.Glass, transparency = 0.2 })
end

builders.lollipop = function(m, base, s)
	Build.cylinder(m, 7 * s, 0.5 * s, base * CF(0, 3.5 * s, 0), rgb(255, 255, 255), { collide = true })
	local colors = { rgb(255, 90, 150), rgb(120, 200, 255), rgb(255, 220, 80), rgb(170, 120, 255) }
	local c = pick(colors, base.Position.X + base.Position.Z)
	Build.cylinderX(m, 0.8 * s, 5 * s, base * CF(0, 8.5 * s, 0) * CFrame.Angles(0, rad(90), 0), c, { shadow = true })
	Build.cylinderX(m, 0.85 * s, 3 * s, base * CF(0, 8.5 * s, 0) * CFrame.Angles(0, rad(90), 0), rgb(255, 255, 255), { shadow = false })
	Build.cylinderX(m, 0.9 * s, 1.4 * s, base * CF(0, 8.5 * s, 0) * CFrame.Angles(0, rad(90), 0), c, { shadow = false })
end

builders.candyCane = function(m, base, s)
	for i = 0, 5 do
		Build.cylinder(m, 1.2 * s, 0.9 * s, base * CF(0, (0.6 + i * 1.2) * s, 0), if i % 2 == 0 then rgb(230, 40, 60) else rgb(255, 255, 255), { collide = i == 0 })
	end
	Build.cylinderX(m, 2 * s, 0.9 * s, base * CF(0.8 * s, 7.4 * s, 0) * CFrame.Angles(0, 0, rad(30)), rgb(230, 40, 60))
	Build.cylinder(m, 1 * s, 0.9 * s, base * CF(1.8 * s, 7.2 * s, 0), rgb(255, 255, 255))
end

builders.gumdrop = function(m, base, s)
	local colors = { rgb(120, 220, 120), rgb(255, 120, 170), rgb(255, 200, 80) }
	local c = pick(colors, base.Position.X * 7 + base.Position.Z)
	Build.ball(m, V(5, 4.4, 5) * s, base * CF(0, 1.4 * s, 0), c, { material = Enum.Material.Glass, transparency = 0.15, collide = true })
	Build.cylinder(m, 1 * s, 5 * s, base * CF(0, 0.5 * s, 0), Build.shade(c, 0.9), { material = Enum.Material.SmoothPlastic })
end

builders.lavaRock = function(m, base, s)
	Build.ball(m, V(4.6, 3, 4) * s, base * CF(0, 1.2 * s, 0), rgb(60, 50, 50), { material = Enum.Material.Basalt, collide = true })
	Build.ball(m, V(1.4, 0.4, 1.2) * s, base * CF(0.6 * s, 2.6 * s, -0.4 * s), rgb(255, 110, 30), { material = Enum.Material.Neon, shadow = false })
end

builders.vent = function(m, base, s)
	Build.cylinder(m, 1.6 * s, 4.4 * s, base * CF(0, 0.8 * s, 0), rgb(70, 58, 56), { material = Enum.Material.Basalt, collide = true })
	local core = Build.cylinder(m, 0.2 * s, 2.6 * s, base * CF(0, 1.62 * s, 0), rgb(255, 120, 30), { material = Enum.Material.Neon, shadow = false })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(rgb(120, 110, 110))
	smoke.LightInfluence = 1
	smoke.Parent = core
end

builders.crystal = function(m, base, s, theme)
	local color = if theme and theme.props == "moon" then rgb(160, 130, 255) else rgb(255, 140, 60)
	for i, spec in { { 0, 4.2, 0 }, { 1, 2.8, 25 }, { -1, 3.2, -30 } } do
		local x, h, tilt = spec[1], spec[2], spec[3]
		Build.block(m, V(1.1, h, 1.1) * s, base * CF(x * s, h / 2 * s, 0) * CFrame.Angles(0, rad(45), rad(tilt)), color, { material = Enum.Material.Glass, transparency = 0.1, collide = i == 1, reflectance = 0.2 })
	end
end

builders.moonRock = function(m, base, s)
	local color = rgb(150, 150, 170)
	Build.ball(m, V(4.4, 2.4, 3.8) * s, base * CF(0, 0.9 * s, 0), color, { material = Enum.Material.Slate, collide = true })
	Build.ball(m, V(1.2, 0.3, 1.2) * s, base * CF(0.6 * s, 2 * s, 0.3 * s), Build.shade(color, 0.7), { material = Enum.Material.Slate, shadow = false })
end

builders.antenna = function(m, base, s)
	Build.cylinder(m, 8 * s, 0.4 * s, base * CF(0, 4 * s, 0), rgb(200, 200, 210), { material = Enum.Material.Metal, collide = true })
	Build.ball(m, V(3.6, 1, 3.6) * s, base * CF(0, 8 * s, 0) * CFrame.Angles(rad(30), 0, 0), rgb(230, 230, 240), { material = Enum.Material.Metal })
	Build.ball(m, V(0.7, 0.7, 0.7) * s, base * CF(0, 8.9 * s, 0), rgb(255, 60, 60), { material = Enum.Material.Neon, shadow = false })
end

builders.rocket = function(m, base, s)
	Build.cylinder(m, 8 * s, 3 * s, base * CF(0, 5 * s, 0), rgb(240, 240, 245), { collide = true })
	Build.ball(m, V(3, 4, 3) * s, base * CF(0, 9.2 * s, 0), rgb(230, 60, 60))
	Build.ball(m, V(1.2, 1.2, 0.4) * s, base * CF(0, 6.2 * s, -1.45 * s), rgb(120, 200, 255), { material = Enum.Material.Glass })
	for i = 0, 2 do
		Build.wedge(m, V(0.3, 2.6, 2) * s, base * CF(0, 1.8 * s, 0) * CFrame.Angles(0, rad(i * 120), 0) * CF(0, 0, -2 * s) * CFrame.Angles(0, rad(180), 0), rgb(230, 60, 60))
	end
end

-- Large backdrop landmarks placed outside the playable walls.
builders.house = function(m, base, s, _theme)
	local wallColors = { rgb(250, 236, 214), rgb(214, 230, 245), rgb(245, 214, 214), rgb(220, 240, 210) }
	local wall = pick(wallColors, base.Position.X)
	Build.block(m, V(16, 10, 14) * s, base * CF(0, 5 * s, 0), wall, { material = Enum.Material.SmoothPlastic })
	local roof = rgb(170, 70, 60)
	Build.wedge(m, V(17, 5, 7.5) * s, base * CF(0, 12.5 * s, 3.75 * s) * CFrame.Angles(0, rad(180), 0), roof)
	Build.wedge(m, V(17, 5, 7.5) * s, base * CF(0, 12.5 * s, -3.75 * s), roof)
	Build.block(m, V(3, 6, 0.4) * s, base * CF(0, 3 * s, -7.1 * s), rgb(130, 80, 50), { material = Enum.Material.Wood })
	for _, x in { -5, 5 } do
		Build.block(m, V(3, 3, 0.4) * s, base * CF(x * s, 6 * s, -7.1 * s), rgb(160, 210, 255), { material = Enum.Material.Glass })
	end
	Build.block(m, V(1.6, 4, 1.6) * s, base * CF(5 * s, 14 * s, 2 * s), rgb(150, 80, 70), { material = Enum.Material.Brick })
end

builders.barn = function(m, base, s)
	local red = rgb(190, 60, 50)
	Build.block(m, V(18, 12, 14) * s, base * CF(0, 6 * s, 0), red, { material = Enum.Material.WoodPlanks })
	Build.wedge(m, V(19, 6, 7.5) * s, base * CF(0, 15 * s, 3.75 * s) * CFrame.Angles(0, rad(180), 0), rgb(90, 90, 100))
	Build.wedge(m, V(19, 6, 7.5) * s, base * CF(0, 15 * s, -3.75 * s), rgb(90, 90, 100))
	Build.block(m, V(7, 8, 0.4) * s, base * CF(0, 4 * s, -7.1 * s), rgb(245, 245, 240), { material = Enum.Material.WoodPlanks })
end

builders.cabin = function(m, base, s)
	local log = rgb(140, 96, 60)
	for i = 0, 4 do
		Build.cylinderX(m, 16 * s, 2 * s, base * CF(0, (1 + i * 2) * s, -6 * s), Build.shade(log, 0.95 + (i % 2) * 0.1), { material = Enum.Material.Wood })
		Build.cylinderX(m, 16 * s, 2 * s, base * CF(0, (1 + i * 2) * s, 6 * s), Build.shade(log, 0.95 + (i % 2) * 0.1), { material = Enum.Material.Wood })
	end
	Build.block(m, V(15, 10, 12) * s, base * CF(0, 5 * s, 0), log, { material = Enum.Material.Wood })
	Build.wedge(m, V(17, 5, 7.5) * s, base * CF(0, 12.5 * s, 3.75 * s) * CFrame.Angles(0, rad(180), 0), rgb(70, 90, 60))
	Build.wedge(m, V(17, 5, 7.5) * s, base * CF(0, 12.5 * s, -3.75 * s), rgb(70, 90, 60))
end

builders.hut = function(m, base, s)
	Build.block(m, V(12, 8, 10) * s, base * CF(0, 5 * s, 0), rgb(230, 200, 150), { material = Enum.Material.WoodPlanks })
	for _, p in { V(-5.5, 0, -4.5), V(5.5, 0, -4.5), V(-5.5, 0, 4.5), V(5.5, 0, 4.5) } do
		Build.cylinder(m, 2 * s, 0.8 * s, base * CF(p.X * s, 0.5 * s, p.Z * s), rgb(150, 110, 70), { material = Enum.Material.Wood })
	end
	Build.wedge(m, V(14, 4, 6) * s, base * CF(0, 11 * s, 3 * s) * CFrame.Angles(0, rad(180), 0), rgb(200, 170, 90), { material = Enum.Material.Fabric })
	Build.wedge(m, V(14, 4, 6) * s, base * CF(0, 11 * s, -3 * s), rgb(200, 170, 90), { material = Enum.Material.Fabric })
end

builders.igloo = function(m, base, s)
	Build.ball(m, V(14, 10, 14) * s, base * CF(0, 1 * s, 0), rgb(240, 248, 255), { material = Enum.Material.Ice })
	Build.cylinderX(m, 5 * s, 5 * s, base * CF(0, 2 * s, -7 * s) * CFrame.Angles(0, rad(90), 0), rgb(230, 240, 250), { material = Enum.Material.Ice })
	Build.cylinderX(m, 5.2 * s, 3 * s, base * CF(0, 1.6 * s, -7 * s) * CFrame.Angles(0, rad(90), 0), rgb(60, 80, 110), { shadow = false })
end

builders.candyHouse = function(m, base, s)
	Build.block(m, V(14, 10, 12) * s, base * CF(0, 5 * s, 0), rgb(170, 110, 70), { material = Enum.Material.SmoothPlastic })
	Build.wedge(m, V(15, 5, 6.5) * s, base * CF(0, 12.5 * s, 3.25 * s) * CFrame.Angles(0, rad(180), 0), rgb(255, 245, 250))
	Build.wedge(m, V(15, 5, 6.5) * s, base * CF(0, 12.5 * s, -3.25 * s), rgb(255, 245, 250))
	for i = -2, 2 do
		Build.ball(m, V(1.2, 1.2, 1.2) * s, base * CF(i * 2.8 * s, 10.3 * s, -6.2 * s), if i % 2 == 0 then rgb(255, 80, 120) else rgb(120, 220, 120), { shadow = false })
	end
	Build.block(m, V(3, 5, 0.4) * s, base * CF(0, 2.5 * s, -6.1 * s), rgb(255, 120, 170))
end

builders.volcano = function(m, base, s)
	local rock = rgb(70, 56, 54)
	local layers = { { 40, 8 }, { 32, 16 }, { 24, 24 }, { 17, 31 } }
	for _, layer in layers do
		Build.cylinder(m, 8 * s, layer[1] * s, base * CF(0, (layer[2] - 4) * s, 0), rock, { material = Enum.Material.Basalt })
	end
	local lava = Build.cylinder(m, 0.6 * s, 12 * s, base * CF(0, 31.2 * s, 0), rgb(255, 110, 20), { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = rgb(255, 120, 40)
	light.Parent = lava
end

builders.dome = function(m, base, s)
	Build.ball(m, V(18, 14, 18) * s, base * CF(0, 1 * s, 0), rgb(180, 220, 255), { material = Enum.Material.Glass, transparency = 0.35 })
	Build.cylinder(m, 1 * s, 19 * s, base * CF(0, 0.5 * s, 0), rgb(200, 200, 210), { material = Enum.Material.Metal })
	Build.block(m, V(3, 5, 3) * s, base * CF(0, 2.5 * s, 0), rgb(240, 240, 245), { material = Enum.Material.Metal })
end

Props.Builders = builders

Props.Landmarks = {
	suburb = "house",
	farm = "barn",
	forest = "cabin",
	beach = "hut",
	snow = "igloo",
	candy = "candyHouse",
	volcano = "volcano",
	moon = "dome",
}

Props.BackdropTrees = {
	suburb = "autumnTree",
	farm = "autumnTree",
	forest = "pine",
	beach = "palm",
	snow = "snowPine",
	candy = "lollipop",
	volcano = "lavaRock",
	moon = "moonRock",
}

function Props.build(kind: string, parent: Instance, base: CFrame, scale: number?, theme: any?): Model
	local builder = builders[kind]
	assert(builder, "Unknown prop kind: " .. tostring(kind))
	local model = Build.model(kind, parent)
	builder(model, base, scale or 1, theme)
	return model
end

return Props
