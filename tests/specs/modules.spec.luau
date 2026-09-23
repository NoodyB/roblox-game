--!nocheck
-- Compiles every script in the Rojo tree and requires every shared module.
-- Catches syntax errors and broken require paths across the whole codebase.

local luau = require("@lune/luau")

return function(t)
	local describe, it, expect, Harness = t.describe, t.it, t.expect, t.Harness

	describe("project", function()
		it("compiles every script and module", function()
			local failures = {}
			for _, entry in Harness.allModules() do
				local ok, err = pcall(luau.compile, entry.source)
				if not ok then
					table.insert(failures, entry.path .. ": " .. tostring(err))
				end
			end
			if #failures > 0 then
				error(table.concat(failures, "\n"))
			end
		end)

		it("requires every shared module without errors", function()
			local shared = Harness.findPath("ReplicatedStorage.Shared")
			expect(shared).toBeTruthy()
			local count = 0
			for _, node in shared:GetDescendants() do
				if node.ClassName == "ModuleScript" then
					Harness.require(node)
					count += 1
				end
			end
			expect(count).toBeGreaterThan(10)
		end)
	end)
end
