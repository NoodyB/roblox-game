--!strict
-- UI theme: "cozy autumn candy" — warm cream cards, chunky rounded shapes, high-contrast text.

local rgb = Color3.fromRGB

local Theme = {
	Colors = {
		Background = rgb(255, 248, 235),
		BackgroundDark = rgb(245, 230, 206),
		Card = rgb(255, 255, 255),
		Text = rgb(74, 46, 31),
		TextLight = rgb(140, 110, 90),
		TextOnDark = rgb(255, 255, 255),
		Stroke = rgb(74, 46, 31),
		Accent = rgb(255, 138, 61),
		AccentDark = rgb(214, 96, 30),
		Green = rgb(76, 194, 107),
		GreenDark = rgb(46, 150, 76),
		Blue = rgb(70, 160, 255),
		BlueDark = rgb(40, 110, 210),
		Purple = rgb(139, 92, 246),
		PurpleDark = rgb(100, 60, 200),
		Gold = rgb(255, 200, 61),
		GoldDark = rgb(214, 150, 20),
		Red = rgb(240, 80, 80),
		RedDark = rgb(190, 50, 50),
		Grey = rgb(190, 180, 170),
		GreyDark = rgb(140, 130, 120),
		Overlay = rgb(30, 20, 15),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamMedium,
		Bold = Enum.Font.GothamBold,
	},
	Corner = 14,
	StrokeThickness = 3,
}

return Theme
