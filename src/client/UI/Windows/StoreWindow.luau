--!strict
-- Robux store. Every item states exactly what it does and costs before the Roblox prompt opens.
-- Items whose id is still 0 (not created in the Creator Dashboard yet) show "Coming soon".
-- Nothing randomized is sold.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Util.Format)
local C = require(script.Parent.Parent.Components)

local Colors = Theme.Colors
local player = Players.LocalPlayer

return function()
	type Card = { buy: C.Button, price: TextLabel, detail: TextLabel?, kind: string, id: number, key: string }
	local cards: { Card } = {}
	local prices: { [number]: number } = {}

	local function fetchPrice(id: number, infoType: Enum.InfoType, card: Card)
		if id == 0 then
			return
		end
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			if ok and info and info.PriceInRobux then
				prices[id] = info.PriceInRobux
				card.price.Text = "R$ " .. tostring(info.PriceInRobux)
			end
		end)
	end

	local function makeCard(parent: Instance, order: number, emoji: string, name: string, description: string, priceHint: number, kind: string, id: number, key: string): Card
		local frame = C.card({ LayoutOrder = order, Parent = parent })
		C.label({ Text = emoji, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(10, 10), Parent = frame })
		C.label({ Text = name, Size = UDim2.new(1, -84, 0, 30), Position = UDim2.fromOffset(76, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		local price = C.label({ Text = "R$ " .. priceHint, TextColor3 = Colors.GreenDark, Size = UDim2.new(1, -84, 0, 24), Position = UDim2.fromOffset(76, 44), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		C.label({
			Text = description,
			Font = Theme.Fonts.Body,
			TextScaled = false,
			TextSize = 16,
			TextWrapped = true,
			TextColor3 = Colors.TextLight,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -20, 0, 58),
			Position = UDim2.fromOffset(10, 80),
			Parent = frame,
		})
		local detail: TextLabel? = nil
		if kind == "coins" then
			detail = C.label({ Text = "", Font = Theme.Fonts.Bold, TextColor3 = Colors.GoldDark, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 138), Parent = frame })
		end
		local card: Card
		local buy = C.button({
			Text = if id == 0 then "Coming soon" else "Buy",
			Size = UDim2.new(1, -20, 0, 46),
			Position = UDim2.new(0, 10, 1, -54),
			Color = if kind == "pass" then Colors.Purple else Colors.Green,
			DarkColor = if kind == "pass" then Colors.PurpleDark else Colors.GreenDark,
			Parent = frame,
			OnClick = function()
				if id == 0 then
					return
				end
				if kind == "pass" then
					MarketplaceService:PromptGamePassPurchase(player, id)
				else
					MarketplaceService:PromptProductPurchase(player, id)
				end
			end,
		})
		buy.setEnabled(id ~= 0)
		card = { buy = buy, price = price, detail = detail, kind = kind, id = id, key = key }
		table.insert(cards, card)
		fetchPrice(id, if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product, card)
		return card
	end

	local function refresh(state: any)
		for _, card in cards do
			if card.kind == "pass" then
				local owned = state.passes and state.passes[card.key]
				if owned then
					card.buy.setText("✓ Owned")
					card.buy.setEnabled(false)
				end
			elseif card.kind == "coins" and card.detail then
				local product = Products.ProductByKey[card.key]
				card.detail.Text = "≈ " .. Format.abbreviate(Economy.coinPackAmount(state, product.amount)) .. " coins right now"
			end
		end
	end

	local function build(content: Frame)
		local scroll = C.scroll({ Parent = content })
		C.list(Enum.FillDirection.Vertical, 10).Parent = scroll
		C.padding(6).Parent = scroll

		local function section(title: string, order: number): Frame
			C.label({ Text = title, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = scroll })
			local grid = C.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1, Parent = scroll })
			C.grid(UDim2.fromOffset(232, 222), 10).Parent = grid
			return grid
		end

		local passes = section("👑 Game Passes (forever)", 1)
		for index, pass in Products.GamePasses do
			makeCard(passes, index, pass.emoji, pass.name, pass.description, pass.priceHint, "pass", pass.id, pass.key)
		end
		local items = section("⚡ Boosts & Coins", 10)
		for index, product in Products.DevProducts do
			makeCard(items, index, product.emoji, product.name, product.description, product.priceHint, product.kind, product.id, product.key)
		end
		C.label({
			Text = "Everything in Sweep Squad can be earned for free. Purchases just speed things up. 💛",
			Font = Theme.Fonts.Bold,
			TextColor3 = Colors.TextLight,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 100,
			Parent = scroll,
		})
	end

	return {
		key = "Store",
		title = "💎 Supply Store",
		color = Colors.Gold,
		darkColor = Colors.GoldDark,
		build = build,
		refresh = refresh,
	}
end
