local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data

local Gun = require(ServerScriptService.Server.Classes.Gun)
local Human = require(script.Parent.Human)

local UP = Vector3.yAxis

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new("Revolver", self, self.Character)
	self.HumanType = "NPC"
	self.CurrentGun:AddGunToInventory()

	print(`New human class initiated for NPC {self.Character.Name}`)
	return self :: any
end

function HumanNPC:AttackPlayer(target: Model)
	assert(target, "[HumanNPC:AttackPlayer] Target is invalid")

	local rightArm = self.BodyParts["RightUpperArm"]
	assert(rightArm, "[HumanNPC:AttackPlayer] Right arm missing, NPC cannot attack target")

	local rightShoulder: AnimationConstraint? = rightArm:FindFirstChildOfClass("AnimationConstraint")
	assert(rightShoulder, "[HumanNPC:AttackPlayer] Right shoulder missing, NPC cannot attack target")
end

function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end
	self.Humanoid:EquipTool(gunTool)

	task.spawn(function()
		while task.wait(1) do
			if not self.CurrentGun then
				return
			end
			self:NPCShoot()
		end
	end)
end

function HumanNPC:EquipThrowable(throwable: Tool?)
	if not throwable then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end
	self.Humanoid:EquipTool(throwable)
end

function HumanNPC:UnEquipCurrentTool()
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
	local handle = tool:WaitForChild("Handle", 10)
	local shootPoint = tool:WaitForChild("ShootPoint", 10)
	local rightArm = self.BodyParts.RightUpperArm

	if not (handle and shootPoint and rightArm) then
		return
	end

	-- Fire weapon logic first
	currentGun:ShootGun()

	-- recoil impulse
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
