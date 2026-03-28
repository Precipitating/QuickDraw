-- inheriting Human and defining Player only data
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local RangeAI = require(ServerScriptService.Server.Classes.AIBehaviour.RangeAI)

local Gun = require(ServerScriptService.Server.Classes.Gun)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local Human = require(script.Parent.Human)
local HumanConstants = require(script.Parent.HumanConstants)

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	Human.AssignBodyParts(self, "NPC")
	self.CurrentGun = Gun.new("Winchester", self, self.Character)
	self.CurrentThrowable = Throwable.new("Dynamite", self)
	self.HumanType = "NPC"
	self.RightArmAimer = self:InitializeRightArmAimer()
	self.TorsoAimer = self:InitializeTorsoAimer()
	self.CurrentGun:AddGunToInventory()
	self.CurrentThrowable:AddThrowableToInventory()
	self.AI = RangeAI.new(self)
	self.NoiseSeed = RandomModule.GetRandom() * 1000
	self:SetNPCNetworkOwnership()
	self:SetWeaponCollisions()
	humanoid.WalkSpeed = HumanConstants.WALKSPEED
	print(`New human class initiated for NPC {self.Character.Name}`)

	return self :: any
end

function HumanNPC:SetNPCNetworkOwnership()
	for _, part in self.BodyParts do
		part:SetNetworkOwner(nil)
	end
end

function HumanNPC:SetWeaponCollisions()
	for _, part in self.CurrentGun.Tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "NPC"
		end
	end
end
function HumanNPC:InitializeRightArmAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local rightArm = self.BodyParts["RightUpperArm"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = rightArm:WaitForChild("RightShoulderAttachment")
	aimer.RigidityEnabled = false
	aimer.Name = "RightArmAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 50
	aimer.Enabled = false
	aimer.Parent = rightArm
	return aimer
end
function HumanNPC:InitializeTorsoAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local upperTorso = self.BodyParts["UpperTorso"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = upperTorso:WaitForChild("WaistRigAttachment")
	aimer.RigidityEnabled = true
	aimer.AlignType = Enum.AlignType.AllAxes
	aimer.Name = "TorsoAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 50
	aimer.Enabled = false
	aimer.Parent = upperTorso
	return aimer
end

function HumanNPC:ToggleRightArmAimer(enable: boolean)
	local rightArmOrientator = self.RightArmAimer
	local torsoAimer = self.TorsoAimer
	assert(rightArmOrientator, "[HumanNPC:ToggleRightArmAimer] RightArmAimer is nil")
	if rightArmOrientator.Enabled == enable then
		return
	end

	if enable then
		rightArmOrientator.Enabled = true

		if not self.Legless then
			torsoAimer.Enabled = true
		end
	else
		rightArmOrientator.Enabled = false
		torsoAimer.Enabled = false
	end
end

function HumanNPC:AimRightArmTowards(target)
	local rightArm = self.BodyParts["RightUpperArm"]
	local origin = rightArm.Position

	local targetPos = target:IsA("Model") and target:GetPivot().Position or target.Position

	local lookCF = CFrame.lookAt(origin, targetPos)

	-- smooth time-based noise
	local t = os.clock() * HumanConstants.SWAY_SPEED
	local seed = self.NoiseSeed

	local yawNoise = math.noise(seed, t, 0)
	local pitchNoise = math.noise(seed, 0, t)

	local swayYaw = yawNoise * HumanConstants.SWAY_AMOUNT
	local swayPitch = pitchNoise * HumanConstants.SWAY_AMOUNT

	lookCF *= CFrame.Angles(math.rad(90) + swayPitch, swayYaw, 0)

	self.RightArmAimer.CFrame = lookCF
	local flattenedLookAt = Vector3.new(targetPos.X, self.HRP.Position.Y, targetPos.Z)
	if not self.Legless then
		self.TorsoAimer.CFrame = CFrame.lookAt(self.HRP.Position, flattenedLookAt)
	else
		self.TorsoAimer.CFrame = CFrame.lookAt(self.BodyParts["UpperTorso"].Position, targetPos)
	end
end
function HumanNPC:AttackPlayer(target: Model | BasePart)
	assert(target, "[HumanNPC:AttackPlayer] Target is invalid")

	self.AI:StartAttackState(target)
end

function HumanNPC:Ragdoll(duration: number)
	local humanoid = self.Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	task.delay(duration, function()
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
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
