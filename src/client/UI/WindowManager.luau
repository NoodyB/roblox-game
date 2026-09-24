--!strict
-- Modal windows (Shop, Critters, Quests, ...). One window at a time, dimmed backdrop, pop-in
-- animation, close via X / backdrop click / the same hotkey. Windows are built once and refreshed
-- from state, so opening is instant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local C = require(script.Parent.Components)

local WindowManager = {}

WindowManager.Opened = Signal.new() -- (key)
WindowManager.Closed = Signal.new() -- (key)

export type WindowDef = {
	key: string,
	title: string,
	color: Color3,
	darkColor: Color3,
	build: (content: Frame) -> (),
	refresh: ((state: { [string]: any }) -> ())?,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

type Entry = { def: WindowDef, root: Frame }

local entries: { [string]: Entry } = {}
local currentKey: string? = nil
local backdrop: TextButton
local gui: ScreenGui
local lastState: { [string]: any }? = nil

function WindowManager.mount(screen: ScreenGui)
	gui = screen
	backdrop = C.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Overlay,
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 1,
		Parent = gui,
	})
	backdrop.Activated:Connect(function()
		WindowManager.close()
	end)
end

function WindowManager.register(def: WindowDef)
	local root = C.card({
		Name = def.key .. "Window",
		Size = UDim2.fromOffset(780, 540),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Background,
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	})
	C.new("UISizeConstraint", { MaxSize = Vector2.new(780, 540) }).Parent = root

	local header = C.card({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = def.color,
		Parent = root,
	})
	C.gradient(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)).Parent = header
	C.outlined({
		Name = "Title",
		Text = def.title,
		Size = UDim2.new(1, -140, 0, 44),
		Position = UDim2.fromOffset(20, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	C.button({
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(52, 46),
		Position = UDim2.new(1, -14, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Colors.Red,
		DarkColor = Theme.Colors.RedDark,
		Parent = header,
		OnClick = function()
			WindowManager.close()
		end,
	})

	local content = C.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -28, 1, -86),
		Position = UDim2.fromOffset(14, 76),
		BackgroundTransparency = 1,
		Parent = root,
	})
	def.build(content)
	entries[def.key] = { def = def, root = root }
	if lastState and def.refresh then
		def.refresh(lastState)
	end
end

function WindowManager.isOpen(key: string?): boolean
	if key then
		return currentKey == key
	end
	return currentKey ~= nil
end

function WindowManager.close()
	if not currentKey then
		return
	end
	local entry = entries[currentKey]
	local key = currentKey
	currentKey = nil
	if entry then
		entry.root.Visible = false
		if entry.def.onClose then
			entry.def.onClose()
		end
	end
	backdrop.Visible = false
	WindowManager.Closed:Fire(key)
end

function WindowManager.open(key: string)
	local entry = entries[key]
	if not entry then
		return
	end
	if currentKey == key then
		return
	end
	WindowManager.close()
	currentKey = key
	backdrop.Visible = true
	entry.root.Visible = true
	C.pop(entry.root)
	if lastState and entry.def.refresh then
		entry.def.refresh(lastState)
	end
	if entry.def.onOpen then
		entry.def.onOpen()
	end
	WindowManager.Opened:Fire(key)
end

function WindowManager.toggle(key: string)
	if currentKey == key then
		WindowManager.close()
	else
		WindowManager.open(key)
	end
end

function WindowManager.refresh(state: { [string]: any })
	lastState = state
	for _, entry in entries do
		if entry.def.refresh and (entry.root.Visible or entry.def.key == currentKey) then
			entry.def.refresh(state)
		end
	end
end

return WindowManager
