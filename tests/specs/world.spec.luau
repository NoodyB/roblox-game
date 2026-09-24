--!nocheck
-- Builds the full map, every prop, every critter and every gear tier with Lune's real Roblox
-- instance model. Any misspelled class/property/enum or wrong value type throws here.

return function(t)
	local describe, it, expect, Harness = t.describe, t.it, t.expect, t.Harness
	local R = function(path)
		return Harness.requirePath("ReplicatedStorage.Shared." .. path)
	end

	local Zones = R("Config.Zones")
	local Critters = R("Config.Critters")
	local Events = R("Config.Events")
	local Upgrades = R("Config.Upgrades")
	local ZoneLayout = R("Logic.ZoneLayout")
	local MapBuilder = R("World.MapBuilder")
	local Props = R("World.Props")
	local CritterModels = R("World.CritterModels")
	local GearModels = R("World.GearModels")

	local function countParts(root)
		local n = 0
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		return n
	end

	-- Roblox engine rules that Lune does not enforce: Ball parts are always uniform spheres, and a
	-- Cylinder's round cross-section uses min(Y, Z). Violations render wrong in the real engine.
	local function checkShapes(root, label)
		local bad = {}
		local nodes = root:GetDescendants()
		if root:IsA("BasePart") then
			table.insert(nodes, root)
		end
		for _, d in nodes do
			if d:IsA("Part") then
				local size = d.Size
				if d.Shape == Enum.PartType.Ball then
					if math.abs(size.X - size.Y) > 1e-3 or math.abs(size.Y - size.Z) > 1e-3 then
						table.insert(bad, label .. ": non-uniform Ball " .. d:GetFullName())
					end
				elseif d.Shape == Enum.PartType.Cylinder then
					if math.abs(size.Y - size.Z) > 1e-3 then
						table.insert(bad, label .. ": elliptic Cylinder " .. d:GetFullName())
					end
				end
			end
		end
		if #bad > 0 then
			error(table.concat(bad, "\n", 1, math.min(#bad, 10)))
		end
	end
	t.checkShapes = checkShapes

	describe("Engine shape rules", function()
		it("map, props, critters and gear only use valid ball and cylinder sizes", function()
			local parent = Instance.new("Folder")
			local refs = MapBuilder.build(parent, { hubDecor = "jackOLantern" })
			checkShapes(refs.map, "map")
			for _, critter in Critters.List do
				checkShapes(CritterModels.build(critter.id, false, nil, CFrame.new(), 1.3), critter.id)
				checkShapes(CritterModels.build(critter.id, true, nil, CFrame.new(), 0.8), critter.id .. " golden")
			end
			for tier = 1, #Upgrades.Vacuums do
				local folder = Instance.new("Folder")
				GearModels.buildVacuum(folder, tier, CFrame.new())
				GearModels.buildBag(folder, math.min(tier, #Upgrades.Bags), CFrame.new())
				checkShapes(folder, "gear " .. tier)
			end
		end)
	end)

	describe("MapBuilder", function()
		local workspace = Instance.new("Folder")
		local refs = MapBuilder.build(workspace)

		it("builds the map with a gate for every locked zone", function()
			expect(refs.map.Parent).toBe(workspace)
			for zoneId = 2, #Zones do
				local gate = refs.gates[zoneId]
				expect(gate).toBeTruthy()
				expect(gate:GetAttribute("ZoneId")).toBe(zoneId)
				expect(gate:HasTag("ZoneGate")).toBe(true)
				expect(gate.CanCollide).toBe(true)
				local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
				expect(prompt).toBeTruthy()
			end
			expect(refs.gates[1]).toBeNil()
		end)

		it("stays within a mobile-friendly part budget", function()
			local parts = countParts(refs.map)
			print(string.format("      map part count: %d", parts))
			expect(parts).toBeLessThan(3500)
			expect(parts).toBeGreaterThan(500)
		end)

		it("anchors every part and keeps decoration non-colliding", function()
			local colliding = 0
			for _, d in refs.map:GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.Anchored).toBe(true)
					if d.CanCollide then
						colliding += 1
					end
				end
			end
			print(string.format("      colliding parts: %d", colliding))
			expect(colliding).toBeLessThan(900)
		end)

		it("creates both leaderboards with 10 rows", function()
			expect(#refs.boards.Units.rows).toBe(10)
			expect(#refs.boards.Rebirths.rows).toBe(10)
		end)

		it("has a neutral spawn and window prompts for every hub building", function()
			expect(refs.spawn.Neutral).toBe(true)
			local windows = {}
			for _, prompt in refs.prompts do
				local key = prompt:GetAttribute("OpenWindow")
				if key then
					windows[key] = true
				end
			end
			for _, key in { "Shop", "Critters", "Rebirth", "Quests", "Store" } do
				expect(windows[key]).toBe(true)
			end
		end)

		it("puts sell pads exactly where the server sells", function()
			local pads = {}
			for _, d in refs.map:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("SellPad") then
					table.insert(pads, d)
				end
			end
			expect(#pads).toBe(#Zones * 2)
			for zoneId = 1, #Zones do
				for _, pad in ZoneLayout.sellPads(zoneId) do
					local found = false
					for _, part in pads do
						if math.abs(part.CFrame.Position.X - pad.x) < 0.01 and math.abs(part.CFrame.Position.Z - pad.z) < 0.01 then
							found = true
						end
					end
					expect(found).toBe(true)
				end
			end
		end)
	end)

	describe("Seasonal map decor", function()
		it("adds hub decorations for every event", function()
			for _, event in Events do
				local parent = Instance.new("Folder")
				local refs = MapBuilder.build(parent, { hubDecor = event.hubDecor })
				local seasonal = refs.map:FindFirstChild("Seasonal")
				expect(seasonal).toBeTruthy()
				expect(#seasonal:GetChildren()).toBe(12)
				checkShapes(seasonal, event.id)
			end
		end)
	end)

	describe("Props", function()
		it("builds every prop kind used by any theme", function()
			local kinds = {}
			for _, set in ZoneLayout.PropSets do
				for _, def in set do
					kinds[def.kind] = true
				end
			end
			for _, kind in Props.Landmarks do
				kinds[kind] = true
			end
			for _, kind in Props.BackdropTrees do
				kinds[kind] = true
			end
			local parent = Instance.new("Folder")
			kinds.jackOLantern = true
			for kind in kinds do
				local model = Props.build(kind, parent, CFrame.new(10, 0, 10), 1, Zones[1].theme)
				expect(countParts(model)).toBeGreaterThan(0)
			end
		end)
	end)

	describe("CritterModels", function()
		it("builds every critter, normal and golden", function()
			for _, critter in Critters.List do
				for _, golden in { false, true } do
					local model = CritterModels.build(critter.id, golden, nil, CFrame.new(0, 0, 0), 1)
					expect(model).toBeTruthy()
					expect(model.PrimaryPart).toBeTruthy()
					local parts = countParts(model)
					expect(parts).toBeGreaterThan(6)
					expect(parts).toBeLessThan(40)
				end
			end
			expect(CritterModels.build("nope", false)).toBeNil()
		end)

		it("scales and positions relative to the base", function()
			local model = CritterModels.build("fox", false, nil, CFrame.new(100, 0, 0), 2)
			local body = model:FindFirstChild("Body")
			expect(body.CFrame.Position.X).toBeCloseTo(100, 0.01)
			expect(body.Size.X).toBeCloseTo(4.2, 0.01)
		end)
	end)

	describe("GearModels", function()
		local function character(r6)
			local model = Instance.new("Model")
			local hand = Instance.new("Part")
			hand.Name = if r6 then "Right Arm" else "RightHand"
			hand.Parent = model
			local torso = Instance.new("Part")
			torso.Name = if r6 then "Torso" else "UpperTorso"
			torso.Parent = model
			return model
		end

		it("builds and welds every vacuum and bag tier", function()
			for tier = 1, math.max(#Upgrades.Vacuums, #Upgrades.Bags) do
				local model = character(tier % 2 == 0)
				GearModels.equip(model, math.min(tier, #Upgrades.Vacuums), math.min(tier, #Upgrades.Bags))
				local gear = model:FindFirstChild("SweepGear")
				expect(gear).toBeTruthy()
				for _, d in gear:GetDescendants() do
					if d:IsA("BasePart") then
						expect(d.Anchored).toBe(false)
						expect(d.Massless).toBe(true)
						expect(d.CanCollide).toBe(false)
						expect(d:FindFirstChildOfClass("WeldConstraint")).toBeTruthy()
					end
				end
			end
		end)

		it("replaces old gear when re-equipped", function()
			local model = character(false)
			GearModels.equip(model, 1, 1)
			GearModels.equip(model, 5, 5)
			local count = 0
			for _, child in model:GetChildren() do
				if child.Name == "SweepGear" then
					count += 1
				end
			end
			expect(count).toBe(1)
		end)
	end)
end
