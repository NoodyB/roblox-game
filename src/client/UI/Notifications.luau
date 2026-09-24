--!strict
-- Toast messages stacked under the top HUD. Max 4 visible; duplicates within 1.5s are merged.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)
local C = require(script.Parent.Components)

local Notifications = {}

local container: Frame
local recent: { [string]: number } = {}
local MAX_VISIBLE = 4

local KIND_COLORS = {
	info = { Theme.Colors.Blue, Theme.Colors.BlueDark },
	success = { Theme.Colors.Green, Theme.Colors.GreenDark },
	error = { Theme.Colors.Red, Theme.Colors.RedDark },
	reward = { Theme.Colors.Gold, Theme.Colors.GoldDark },
}

function Notifications.mount(gui: ScreenGui)
	container = C.new("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(460, 300),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { C.list(Enum.FillDirection.Vertical, 6) })
end

function Notifications.show(kind: string, text: string, duration: number?)
	if not container then
		return
	end
	local now = os.clock()
	if recent[text] and now - recent[text] < 1.5 then
		return
	end
	recent[text] = now

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_VISIBLE then
		toasts[1]:Destroy()
	end

	local colors = KIND_COLORS[kind] or KIND_COLORS.info
	local toast = C.card({
		Name = "Toast",
		Size = UDim2.fromOffset(440, 44),
		BackgroundColor3 = colors[1],
		LayoutOrder = math.floor(now * 1000) % 1_000_000_000,
		Children = {
			C.gradient(Color3.new(1, 1, 1), Color3.fromRGB(225, 225, 225)),
		},
	})
	C.outlined({
		Text = text,
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = toast,
	})
	toast.Parent = container
	C.pop(toast)

	task.delay(duration or 3, function()
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			tween:Play()
			for _, d in toast:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end
			tween.Completed:Wait()
			toast:Destroy()
		end
	end)
end

return Notifications
