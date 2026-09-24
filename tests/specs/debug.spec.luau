--!nocheck
-- Studio-only debug helpers must work in Studio and be inert on live servers.

return function(t)
	local describe, it, expect, Harness, Mocks = t.describe, t.it, t.expect, t.Harness, t.Mocks
	local mocks = Mocks.install(Harness, { studio = true })
	local R = function(path)
		return Harness.requirePath("ServerScriptService.Server.Services." .. path)
	end
	local Net = R("Net")
	Net.fire = function() end
	Net.fireAll = function() end
	Net.notify = function() end
	local DataService = R("DataService")
	DataService._wait = function() end
	local PlayerService = R("PlayerService")
	local DebugService = R("DebugService")
	R("PassService"):Init()
	DataService:Init()
	PlayerService:Init()
	DebugService:Init()

	describe("DebugService (Studio)", function()
		it("applies debug attributes to the profile", function()
			local player = mocks.Players.add(77)
			mocks.Players.PlayerAdded:Fire(player)
			DataService._onPlayerAdded(player)
			local profile = DataService.get(player)
			expect(profile).toBeTruthy()
			player:SetAttribute("DebugCoins", 1e9)
			player:SetAttribute("DebugMaxZone", 99)
			player:SetAttribute("DebugCritters", true)
			player:SetAttribute("DebugTokens", 5)
			expect(profile.coins).toBe(1e9)
			expect(profile.maxZone).toBe(8)
			expect(profile.critters.whale.count).toBe(1)
			expect(profile.rebirthTokens).toBe(5)
			expect(player:GetAttribute("Coins")).toBe(1e9)
		end)
	end)
end
