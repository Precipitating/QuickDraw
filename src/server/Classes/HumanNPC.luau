local Debris = game:GetService("Debris")
-- inheriting Human and defining Player only data
local Gun = require(script.Parent.Gun)
local Human = require(script.Parent.Human)
local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new(self, self.Character)
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
			self.CurrentGun:ShootGun()
		end
	end)
end

function HumanNPC:OnDeath()
	Debris:AddItem(self.Character, 30)
	Human.OnDeath(self)
end
return HumanNPC
