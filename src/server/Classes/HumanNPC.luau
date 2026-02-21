local Debris = game:GetService("Debris")
-- inheriting Human and defining Player only data
local Gun = require(script.Parent.Gun)
local Human = require(script.Parent.Human)

local UP = Vector3.yAxis

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new(self, self.Character)
	self.HumanType = "NPC"
	self.CurrentGun:AddGunToInventory()

	print(`New human class initiated for NPC {self.Character.Name}`)
	return self :: any
end
function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end
	self.Humanoid:EquipTool(gunTool)
	local rightArmConstraint: AnimationConstraint? =
		self.Character["RightUpperArm"]:FindFirstChildOfClass("AnimationConstraint")
	if not rightArmConstraint then
		error("Missing NPC right arm anim constraint")
	end

	rightArmConstraint.Transform = CFrame.new(rightArmConstraint.Transform.Position) * CFrame.Angles(math.rad(90), 0, 0)

	task.spawn(function()
		while task.wait(1) do
			if not self.CurrentGun then
				return
			end
			self:NPCShoot()
		end
	end)
end

function HumanNPC:UnEquipGun()
	self.Humanoid:UnEquipTools()
end

function HumanNPC:NPCShoot()
	local currentGun = self.CurrentGun
	if not currentGun then
		return
	end

	local tool = currentGun.Tool
	if not tool then
		return
	end

	-- Cache these once on equip in production (see note below)
	local handle = tool:FindFirstChild("Handle")
	local shootPoint = tool:FindFirstChild("ShootPoint")
	local rightArm = self.BodyParts.RightUpperArm

	if not (handle and shootPoint and rightArm) then
		return
	end

	-- Fire weapon logic first
	currentGun:ShootGun()

	-- Recoil impulse (mass-scaled for consistency)
	local handleImpulse = handle.AssemblyMass * UP * 10
	handle:ApplyImpulseAtPosition(handleImpulse, shootPoint.WorldPosition)

	local armImpulse = rightArm.AssemblyMass * UP * 100
	rightArm:ApplyImpulse(armImpulse)
end

function HumanNPC:OnDeath()
	Debris:AddItem(self.Character, 30)
	Human.OnDeath(self)
end
return HumanNPC
