--!strict
-- Reusable UI kit. Chunky rounded "candy" style: cards with thick outlines, 3D buttons with a
-- darker base, FredokaOne headings. Everything is sized in design pixels for a 800px-tall screen
-- and scaled by Responsive (UIScale), so it works from phones to 4K monitors.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

local C = {}
local Colors = Theme.Colors

type Props = { [string]: any }

-- Generic constructor: C.new("Frame", { Size = ..., Parent = ... }, { children })
function C.new(className: string, props: Props?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function C.corner(radius: number?): UICorner
	return C.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner) })
end

function C.round(): UICorner
	return C.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function C.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return C.new("UIStroke", {
		Color = color or Colors.Stroke,
		Thickness = thickness or Theme.StrokeThickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function C.textStroke(color: Color3?, thickness: number?): UIStroke
	return C.new("UIStroke", {
		Color = color or Colors.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function C.padding(all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return C.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function C.list(direction: Enum.FillDirection?, spacing: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return C.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function C.grid(cellSize: UDim2, spacing: number?): UIGridLayout
	return C.new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(spacing or 10, spacing or 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

function C.gradient(top: Color3, bottom: Color3): UIGradient
	return C.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function C.label(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextColor3 = Colors.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}
	for k, v in props do
		defaults[k] = v
	end
	local children = defaults.Children
	defaults.Children = nil
	return C.new("TextLabel", defaults, children)
end

-- Bold white text with a dark outline, readable on any background.
function C.outlined(props: Props): TextLabel
	local strokeColor = props.StrokeColor or Colors.Stroke
	local strokeThickness = props.StrokeThickness or 2.5
	props.StrokeColor = nil
	props.StrokeThickness = nil
	props.TextColor3 = props.TextColor3 or Colors.TextOnDark
	local label = C.label(props)
	C.textStroke(strokeColor, strokeThickness).Parent = label
	return label
end

local CARD_OPTIONS = { Children = true, CornerRadius = true, NoStroke = true, StrokeColor = true }

function C.card(props: Props): Frame
	local defaults: Props = {
		BackgroundColor3 = Colors.Card,
		BorderSizePixel = 0,
	}
	for k, v in props do
		if not CARD_OPTIONS[k] then
			defaults[k] = v
		end
	end
	local frame = C.new("Frame", defaults, props.Children or {})
	C.corner(props.CornerRadius).Parent = frame
	if props.NoStroke ~= true then
		C.stroke(props.StrokeColor).Parent = frame
	end
	return frame
end

export type Button = {
	root: Frame,
	button: TextButton,
	label: TextLabel,
	setText: (text: string) -> (),
	setColor: (color: Color3, dark: Color3) -> (),
	setEnabled: (enabled: boolean) -> (),
}

-- Chunky 3D button. onClick fires on release; disabled buttons ignore input.
function C.button(props: Props): Button
	local color = props.Color or Colors.Green
	local dark = props.DarkColor or Colors.GreenDark
	local root = C.new("Frame", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local base = C.new("Frame", {
		Name = "Base",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = dark,
		BorderSizePixel = 0,
		Parent = root,
	}, { C.corner(props.CornerRadius), C.stroke(Colors.Stroke, 3) })
	local button: TextButton = C.new("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = root,
	}, { C.corner(props.CornerRadius), C.stroke(Colors.Stroke, 3) })
	local label = C.outlined({
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = props.Font or Theme.Fonts.Title,
		Parent = button,
	})
	local enabled = true
	local pressInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseButton1Down:Connect(function()
		if enabled then
			TweenService:Create(button, pressInfo, { Position = UDim2.fromOffset(0, 4) }):Play()
		end
	end)
	local function release()
		TweenService:Create(button, pressInfo, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	button.MouseLeave:Connect(release)
	button.MouseButton1Up:Connect(release)
	button.Activated:Connect(function()
		if enabled and props.OnClick then
			props.OnClick()
		end
	end)

	local api: Button = {
		root = root,
		button = button,
		label = label,
		setText = function(text: string)
			label.Text = text
		end,
		setColor = function(c: Color3, d: Color3)
			button.BackgroundColor3 = c
			base.BackgroundColor3 = d
		end,
		setEnabled = function(value: boolean)
			enabled = value
			button.BackgroundTransparency = if value then 0 else 0.35
			label.TextTransparency = if value then 0 else 0.35
		end,
	}
	return api
end

export type ProgressBar = { root: Frame, fill: Frame, label: TextLabel, set: (fraction: number, text: string?) -> () }

function C.progress(props: Props): ProgressBar
	local root = C.new("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.fromOffset(240, 26),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = props.Background or Colors.BackgroundDark,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, { C.round(), C.stroke(Colors.Stroke, props.StrokeThickness or 3) })
	local fill = C.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or Colors.Green,
		BorderSizePixel = 0,
		Parent = root,
	}, { C.round() })
	local label = C.outlined({
		Name = "Text",
		Size = UDim2.new(1, -10, 1, -6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = root,
	})
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
	local current = -1
	local api: ProgressBar = {
		root = root,
		fill = fill,
		label = label,
		set = function(fraction: number, text: string?)
			local f = math.clamp(fraction, 0, 1)
			if math.abs(f - current) > 0.001 then
				current = f
				TweenService:Create(fill, tweenInfo, { Size = UDim2.fromScale(f, 1) }):Play()
			end
			if text then
				label.Text = text
			end
		end,
	}
	return api
end

-- Round red counter badge for buttons ("3").
function C.badge(parent: Instance): TextLabel
	local badge = C.outlined({
		Name = "Badge",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -6, 0, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0,
		BackgroundColor3 = Colors.Red,
		Text = "!",
		ZIndex = 10,
		Visible = false,
		Parent = parent,
	})
	C.round().Parent = badge
	return badge
end

function C.scroll(props: Props): ScrollingFrame
	local defaults: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Colors.TextLight,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		defaults[k] = v
	end
	local children = defaults.Children
	defaults.Children = nil
	return C.new("ScrollingFrame", defaults, children)
end

function C.pop(guiObject: GuiObject, scale: UIScale?)
	local s = scale or guiObject:FindFirstChildOfClass("UIScale") or C.new("UIScale", { Parent = guiObject })
	s.Scale = 0.85
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

return C
