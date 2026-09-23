--!strict
-- Thin, failure-proof wrapper over Roblox AnalyticsService so gameplay code never breaks because
-- of analytics. These events feed the Creator Dashboard (funnels, economy, custom events), which is
-- how real retention/monetization data will be measured after launch.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.FunnelSteps = {
	"Joined",
	"FirstCollect",
	"FirstSell",
	"FirstUpgrade",
	"UnlockedZone2",
	"FirstCritter",
	"FirstQuestClaim",
	"FirstRebirth",
}

local function safe(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		-- Analytics failures are expected in Studio / when APIs change; never propagate.
		Analytics.lastError = tostring(err)
	end
end

Analytics.lastError = nil :: string?

function Analytics.onboarding(player: Player, stepName: string)
	local step = table.find(Analytics.FunnelSteps, stepName)
	if not step then
		return
	end
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

-- flow: "Source" (coins gained) or "Sink" (coins spent)
function Analytics.economy(player: Player, flow: string, amount: number, balance: number, transaction: string, sku: string?)
	if amount <= 0 then
		return
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[flow],
			"Coins",
			math.floor(amount),
			math.floor(balance),
			transaction,
			sku
		)
	end)
end

function Analytics.progression(player: Player, path: string, status: string, level: number)
	safe(function()
		AnalyticsService:LogProgressionEvent(
			player,
			path,
			(Enum.AnalyticsProgressionType :: any)[status],
			level
		)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return Analytics
