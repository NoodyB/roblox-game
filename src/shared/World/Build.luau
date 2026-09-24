--!strict
-- Tiny helpers for building stylized geometry out of primitive parts.
-- Every helper takes a `base` CFrame and a local offset so models are built in place
-- (no PivotTo needed), and returns the created part.

local Build = {}

export type PartOptions = {
	material: Enum.Material?,
	collide: boolean?,
	shadow: boolean?,
	transparency: number?,
	name: string?,
	reflectance: number?,
}

local function apply(p: BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOptions?)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = (opts and opts.material) or Enum.Material.SmoothPlastic
	p.CanCollide = (opts and opts.collide) == true
	p.CanQuery = (opts and opts.collide) == true
	p.CanTouch = false
	p.CastShadow = if opts and opts.shadow ~= nil then opts.shadow else true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts and opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts and opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	p.Name = (opts and opts.name) or "Part"
	p.Parent = parent
end

function Build.block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOptions?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	apply(p, parent, size, cf, color, opts)
	return p
end

-- Sphere or ellipsoid. Roblox forces Ball-shaped parts to a uniform size, so non-uniform sizes use
-- a Block part with a Sphere SpecialMesh (which stretches to the part's size) instead.
function Build.ball(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOptions?): Part
	local p = Instance.new("Part")
	if Build.isUniform(size) then
		p.Shape = Enum.PartType.Ball
	else
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	apply(p, parent, size, cf, color, opts)
	return p
end

function Build.isUniform(size: Vector3): boolean
	return math.abs(size.X - size.Y) < 1e-3 and math.abs(size.Y - size.Z) < 1e-3
end

-- Vertical cylinder of the given height and diameter, with its center at cf.
function Build.cylinder(parent: Instance, height: number, diameter: number, cf: CFrame, color: Color3, opts: PartOptions?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	apply(p, parent, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, opts)
	return p
end

-- Cylinder lying along its local X axis (for axles, logs, nozzles).
function Build.cylinderX(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, opts: PartOptions?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	apply(p, parent, Vector3.new(length, diameter, diameter), cf, color, opts)
	return p
end

function Build.wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: PartOptions?): WedgePart
	local p = Instance.new("WedgePart")
	apply(p, parent, size, cf, color, opts)
	return p
end

function Build.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function Build.folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

-- Returns a slightly lighter/darker variant of a color (factor > 1 lightens).
function Build.shade(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- Adds a billboard-free text sign on a part face.
function Build.surfaceText(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.TextStrokeTransparency = 0.6
	label.Parent = gui
	return label
end

return Build
