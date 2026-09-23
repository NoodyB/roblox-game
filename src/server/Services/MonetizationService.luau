--!strict
-- Developer product receipts. Follows Roblox's required pattern:
--   * Return PurchaseGranted ONLY after the grant is durably saved.
--   * Return NotProcessedYet on any failure (Roblox retries later, possibly in another server).
--   * Every PurchaseId is recorded in the player's profile, so repeat callbacks never double-grant.
-- Game passes are handled by PassService. Nothing randomized is ever sold.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Util.Format)

local Net = require(script.Parent.Net)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local Events = require(script.Parent.Events)
local Analytics = require(script.Parent.Analytics)

local MonetizationService = {}

-- Applies a product to a profile. Returns a message for the player, or nil if the product is invalid.
function MonetizationService.grant(player: Player, profile: any, product: Products.DevProduct): string?
	if product.kind == "coins" then
		local coins = Economy.coinPackAmount(profile, product.amount)
		profile.coins += coins
		profile.stats.lifetimeCoins += coins
		Analytics.economy(player, "Source", coins, profile.coins, "IAP", product.key)
		return string.format("+%s coins!", Format.abbreviate(coins))
	elseif product.kind == "boost" and product.boost and profile.boosts[product.boost] ~= nil then
		profile.boosts[product.boost] += product.amount
		return product.name .. " activated!"
	elseif product.kind == "storm" then
		-- Server-wide effect; the purchase itself is still recorded on the buyer's profile.
		task.defer(PlayerService.startStorm, product.amount, player.DisplayName)
		return "Golden Storm summoned for everyone!"
	end
	return nil
end

local function recordReceipt(profile: any, purchaseId: string)
	table.insert(profile.receipts, purchaseId)
	while #profile.receipts > GameConfig.MaxReceiptHistory do
		table.remove(profile.receipts, 1)
	end
end

function MonetizationService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local product = Products.ProductById[receiptInfo.ProductId]
	if not product then
		warn("[Monetization] receipt for unknown product id " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.waitFor(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if table.find(profile.receipts, purchaseId) then
		-- Already granted (e.g. the previous PurchaseGranted response was lost). Make sure it is saved.
		if DataService.saveNow(player) or DataService.isTemporary() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local message = MonetizationService.grant(player, profile, product)
	if not message then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	recordReceipt(profile, purchaseId)
	profile.stats.purchases += 1
	PlayerService.refresh(player)

	if not DataService.saveNow(player) and not DataService.isTemporary() then
		-- The grant stays in memory with its receipt id (so it cannot double-grant here) and will be
		-- persisted by the next autosave; Roblox will call again and hit the "already granted" path.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Net.fire("Effect", player, "purchase", { text = message, robux = true })
	Events.Purchased:Fire(player, product.key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt
end

return MonetizationService
