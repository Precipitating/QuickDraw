-- inheriting Human and defining Player only data
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local RangeAI = require(ServerScriptService.Server.Classes.AIBehaviour.RangeAI)

local Gun = require(ServerScriptService.Server.Classes.Gun)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local Human = require(script.Parent.Human)

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new("Revolver", self, self.Character)
	self.CurrentThrowable = Throwable.new("Dynamite", self)
	self.HumanType = "NPC"
	self.RightArmAimer = self:InitializeRightArmAimer()
	self.CurrentGun:AddGunToInventory()
	self.CurrentThrowable:AddThrowableToInventory()
	self.AI = RangeAI.new(self)
	print(`New human class initiated for NPC {self.Character.Name}`)

	return self :: any
end
function HumanNPC:InitializeRightArmAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local rightArm = self.BodyParts["RightUpperArm"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = rightArm:WaitForChild("RightShoulderAttachment")
	aimer.RigidityEnabled = true
	aimer.Name = "RightArmAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 50
	aimer.Enabled = false
	aimer.Parent = rightArm
	return aimer
end

function HumanNPC:AttackPlayer(target: Model | BasePart)
	assert(target, "[HumanNPC:AttackPlayer] Target is invalid")

	self.AI:StartAttackState(target)
end

function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end
	self.Humanoid:EquipTool(gunTool)
end

function HumanNPC:UnEquipCurrentTool()
	self.Humanoid:UnEquipTools()
end

function HumanNPC:OnDeath()
	self.AI.CurrentState = "Dead"
	Debris:AddItem(self.Character, 30)

	Human.OnDeath(self)
end

return HumanNPC
