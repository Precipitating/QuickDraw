local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AwardHandler = require(ServerScriptService.Server.AwardHandler.AwardHandler)
local AnimalAI = require(ServerScriptService.Server.Classes.AIBehaviour.AnimalAI)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local AnimalData = require(script.Parent.AnimalData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Animal = {}
Animal.__index = Animal

function Animal.new(model: Model?, type: string, requiresAI: boolean?)
	local self = setmetatable({}, Animal)
	assert(model, "Missing animal model")
	assert(type, "Missing animal type")
	local animalData = AnimalData[type]
	if not animalData then
		warn("Animal type does not exist!")
		return
	end

	self.Character = model
	self.Name = model.Name
	self.Janitor = Janitor.new()
	self.IsRagdolled = false
	self.Health = animalData.Health
	self.MaxHP = animalData.Health
	self.Attacking = false
	self.Dead = false
	self.Target = workspace:FindFirstChild("Target")
	self.ClassType = "Animal"
	self.Type = type
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.AIEnabled = requiresAI
	self.Animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")

	self.HRP = model:FindFirstChild("HumanoidRootPart")
	self.BodyParts = {}

	if requiresAI then
		self.TorsoAimer = self:InitializeTorsoAimer()
		self.AttackRunSpeed = animalData.AttackRunSpeed
		self.AI = AnimalAI.new(self, type)
	end
	self.Humanoid.MaxSlopeAngle = 50
	self.VoicelineSound = self:SetupVoicelineSound()
	self:Initialize()

	return self
end
function Animal:SetupVoicelineSound()
	local sound = Instance.new("Sound")
	sound.Name = "VoicelineSound"
	sound.Parent = self.HRP
	return sound
end
function Animal:InitializeTorsoAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = self.HRP.RootRigAttachment
	aimer.RigidityEnabled = true
	aimer.AlignType = Enum.AlignType.AllAxes
	aimer.Name = "TorsoAimer"
	aimer.Responsiveness = 150
	aimer.Enabled = false
	aimer.Parent = self.HRP
	warn()
	return aimer
end

local function FlattenCFrameY(originalCFrame: CFrame): CFrame
	local lookVector = originalCFrame.LookVector
	-- Calculate the angle on the flat X/Z plane
	local yaw = math.atan2(-lookVector.X, -lookVector.Z)

	-- Create a new CFrame with only the Y rotation (yaw) and original position
	return CFrame.new(originalCFrame.Position) * CFrame.Angles(0, yaw, 0)
end

function Animal:UpdateHealth(value: number, hitBy: Player?)
	self.Health = math.clamp(self.Health + value, 0, self.MaxHP)

	warn("Animal HP =" .. self.Health)
	if self.Health <= 0 then
		self:Die(hitBy)
	end
end

-- Allows the ball sockets to wander freely after disabling the AnimationConstraints
-- Also enables collision on legs so legs dont go through ground
function Animal:DeathRagdoll()
	local character = self.Character
	if not character then
		return
	end

	self.Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

	-- Disable constraints
	for _, instance in self.Character:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.CollisionGroup = "Dead"
		end
		if instance:IsA("AnimationConstraint") then
			instance.Enabled = false
			if instance.Parent and instance.Parent:IsA("BasePart") then
				local parent = instance.Parent
				if not parent.CanCollide then
					parent.CanCollide = true
				end
			end
		elseif instance:IsA("BallSocketConstraint") then
			instance.MaxFrictionTorque = 5
		end
	end
end

function Animal:Die(killer: Player?)
	if self.Dead then
		return
	end
	if self.RequiresAI then
		if not self.AI or not self.AI.StateMachine or not self.AI.StateMachine.Transition then
			return
		end
		self.AI.StateMachine:Transition("Dead")
	end
	self.Dead = true
	self.Humanoid.EvaluateStateMachine = false
	self:DeathRagdoll()

	CollectionService:AddTag(self.Character, "Dead")

	ServerSoundHandler:Play3DOneShotToOthers(nil, `{self.ClassType}Dead`, self.Character:GetPivot().Position, nil)

	if killer and killer:IsA("Player") then
		AwardHandler.AwardAnimalKill(self.Type, killer)
	end

	task.delay(30, function()
		self:Destroy()
	end)
end

function Animal:Attack(target: Model? | BasePart)
	warn("Animal Attack base class function called. You should not see this")
end

function Animal:ToggleTorsoAimer(enable: boolean)
	local torsoAimer = self.TorsoAimer
	assert(torsoAimer, "[Animal:ToggleTorsoAimer] torsoAimer is nil")
	if torsoAimer.Enabled == enable then
		return
	end

	torsoAimer.Enabled = enable

	if not enable then
		torsoAimer.CFrame = CFrame.identity
	end

	--warn(`TorsoAimer new state = {torsoAimer.Enabled}`)
end

function Animal:SetFlattenedTorsoAimer(targetCFrame: CFrame)
	if not self or not self.TorsoAimer or not self.HRP then
		return false
	end

	local originPosition = self.HRP.Position
	local lookAt = CFrame.lookAt(originPosition, targetCFrame.Position)

	self:ToggleTorsoAimer(true)
	self.TorsoAimer.CFrame = FlattenCFrameY(lookAt)

	repeat
		task.wait()
	until not self.HRP or Utility.IsVectorNear(self.HRP.AssemblyAngularVelocity, 0.05)

	return true
end
--
function Animal:Initialize()
	self.Janitor:Add(self.Character)
end

-- Note: AnimalHandler automatically removes this animal from ActiveAnimals when the model is destroyed thanks to InstanceRemoved connection
function Animal:Destroy()
	self.Janitor:Destroy()

	table.clear(self)
	setmetatable(self, nil)
end
return Animal
