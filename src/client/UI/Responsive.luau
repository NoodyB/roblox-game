--!strict
-- Keeps UI proportional on every screen. All UI is authored for a 800px-tall "design" screen;
-- a UIScale on each ScreenGui scales it to the real viewport. Touch devices get slightly larger UI
-- so buttons stay comfortable touch targets (>= ~44pt).

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Responsive = {}

local DESIGN_HEIGHT = 800
local DESIGN_WIDTH = 1280
local scales: { UIScale } = {}

Responsive.isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

function Responsive.compute(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT)
	local scale = math.min(viewport.Y / DESIGN_HEIGHT, viewport.X / DESIGN_WIDTH * 1.25)
	if Responsive.isTouch then
		scale *= 1.12
	end
	return math.clamp(scale, 0.55, 1.35)
end

-- Is the screen narrow (e.g. portrait phone)? Layouts can adapt.
function Responsive.isCompact(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	return camera.ViewportSize.X < 700
end

function Responsive.attach(gui: ScreenGui): UIScale
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = Responsive.compute()
	uiScale.Parent = gui
	table.insert(scales, uiScale)
	return uiScale
end

local function update()
	local value = Responsive.compute()
	for _, s in scales do
		s.Scale = value
	end
end

function Responsive.start()
	local function hook(camera: Camera?)
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	hook(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hook(Workspace.CurrentCamera)
	end)
end

-- Creates a ScreenGui in PlayerGui with sane defaults and responsive scaling.
function Responsive.screen(name: string, displayOrder: number?, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder or 0
	Responsive.attach(gui)
	gui.Parent = parent
	return gui
end

return Responsive
