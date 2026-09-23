--!strict
-- The vacuum held in the right hand and the debris bag on the back. Built from primitives and
-- welded to the character (massless, non-colliding) so it never affects movement physics.
-- The bag's "Body" part is scaled locally by each client to show how full the bag is.

local Shared = script.Parent.Parent
local Upgrades = require(Shared.Config.Upgrades)
local Build = require(script.Parent.Build)

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local rad = math.rad

local GearModels = {}

GearModels.BagBaseSize = V(1.8, 2.2, 1.2)

local function prep(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

-- Builds the vacuum around `grip` (the CFrame where the hand holds it).
function GearModels.buildVacuum(parent: Instance, tier: number, grip: CFrame): Model
	local def = Upgrades.Vacuums[tier] or Upgrades.Vacuums[1]
	local color = def.color
	local m = Build.model("Vacuum", parent)
	if tier == 1 then
		-- rake
		Build.cylinder(m, 5, 0.25, grip * CF(0, -1.2, -0.6) * CFrame.Angles(rad(-35), 0, 0), rgb(170, 120, 70), { material = Enum.Material.Wood, name = "Handle" })
		Build.block(m, V(1.8, 0.2, 0.3), grip * CF(0, -3.2, -2.1), rgb(120, 120, 130), { material = Enum.Material.Metal, name = "Head" })
		for i = -3, 3 do
			Build.block(m, V(0.08, 0.5, 0.08), grip * CF(i * 0.25, -3.5, -2.1), rgb(120, 120, 130), { material = Enum.Material.Metal, name = "Tine" })
		end
	elseif tier == 2 then
		-- broom
		Build.cylinder(m, 5, 0.25, grip * CF(0, -1.2, -0.6) * CFrame.Angles(rad(-35), 0, 0), rgb(196, 150, 90), { material = Enum.Material.Wood, name = "Handle" })
		Build.block(m, V(1.6, 1.2, 0.6), grip * CF(0, -3.3, -2.1) * CFrame.Angles(rad(-35), 0, 0), rgb(230, 190, 90), { material = Enum.Material.Fabric, name = "Head" })
	else
		-- vacuum / blower: body + hose + nozzle, fancier with tier
		Build.block(m, V(0.3, 1.2, 0.3), grip, rgb(60, 60, 70), { name = "Handle" })
		local body = Build.ball(m, V(1.5, 1.3, 2), grip * CF(0, 0.1, 0.9), color, { name = "Head" })
		Build.cylinderX(m, 2.8, 0.55, grip * CF(0, -0.5, -1.2) * CFrame.Angles(0, rad(90), rad(-25)), Build.shade(color, 0.8), { name = "Nozzle" })
		local tip = Build.cylinderX(m, 0.4, 0.9, grip * CF(0, -1.1, -2.5) * CFrame.Angles(0, rad(90), rad(-25)), rgb(40, 40, 50), { name = "Tip" })
		if tier >= 4 then
			Build.cylinderX(m, 0.2, 1.4, grip * CF(0, 0.1, 0.9) * CFrame.Angles(0, rad(90), 0), rgb(255, 255, 255), { material = Enum.Material.Neon, name = "Ring" })
		end
		if tier >= 7 then
			for _, side in { -1, 1 } do
				Build.wedge(m, V(0.15, 0.8, 1.2), grip * CF(side * 0.8, 0.5, 1.3), Build.shade(color, 1.2), { name = "Fin" })
			end
		end
		if tier >= 9 then
			Build.ball(m, V(0.8, 0.8, 0.8), grip * CF(0, 0.9, 0.9), rgb(255, 255, 255), { material = Enum.Material.Neon, name = "Core" })
		end
		body:SetAttribute("Tier", tier)
		local attachment = Instance.new("Attachment")
		attachment.Name = "NozzleAttachment"
		attachment.Parent = tip
	end
	return m
end

function GearModels.buildBag(parent: Instance, tier: number, back: CFrame): Model
	local def = Upgrades.Bags[tier] or Upgrades.Bags[1]
	local m = Build.model("Bag", parent)
	local body = Build.ball(m, GearModels.BagBaseSize, back * CF(0, 0, 0.9), def.color, { material = Enum.Material.Fabric, name = "Body" })
	body:SetAttribute("BaseSize", GearModels.BagBaseSize)
	Build.block(m, V(1.2, 0.3, 0.3), back * CF(0, 1.1, 0.9), Build.shade(def.color, 0.7), { material = Enum.Material.Fabric, name = "Tie" })
	for _, x in { -0.55, 0.55 } do
		Build.block(m, V(0.25, 2, 0.15), back * CF(x, 0.2, -0.55), rgb(80, 60, 40), { material = Enum.Material.Fabric, name = "Strap" })
	end
	return m
end

local function weldAll(model: Instance, target: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = target
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

-- Replaces the gear on a character. Works for R15 (RightHand/UpperTorso) and R6 (Right Arm/Torso).
function GearModels.equip(character: Model, vacuumTier: number, bagTier: number)
	local existing = character:FindFirstChild("SweepGear")
	if existing then
		existing:Destroy()
	end
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not hand or not torso then
		return
	end
	local folder = Build.folder("SweepGear", nil)
	local isR6 = hand.Name == "Right Arm"
	local grip = hand.CFrame * CF(0, if isR6 then -1 else -0.2, -0.3)
	local vacuum = GearModels.buildVacuum(folder, vacuumTier, grip)
	local bag = GearModels.buildBag(folder, bagTier, torso.CFrame * CF(0, 0.2, 0))
	prep(folder)
	weldAll(vacuum, hand)
	weldAll(bag, torso)
	folder.Parent = character
end

return GearModels
