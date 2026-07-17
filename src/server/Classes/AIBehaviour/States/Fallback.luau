local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

type HumanNPC = ClassTypes.HumanNPC
type Animal = ClassTypes.Animal

local Fallback = setmetatable({}, BaseState)
Fallback.__index = Fallback

function Fallback.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Fallback)
	return self
end

function Fallback:FindFallbackPosition(human, target)
	-- 1. Find a suitable position around player to go to
	local randomDistWithinRange = RandomModule.GetRandomIntBetween(self.AI.MinAttackDistance, self.AI.MaxAttackDistance)
	local safePos = self.AI:FindAnglePosition(human.HRP.Position, target, nil, randomDistWithinRange, false)

	-- 1.1 (TERMINATION) If we can't find a fallback position, got to attack state (shoots at current position)
	if not safePos then
		warn("Cornered, shoot from current position, ignoring distance requirements")
		self.Machine:Transition(self.AI.AttackState.Name, { Target = target, Cornered = true })
		return false
	end

	return safePos
end

function Fallback:MoveToFallbackPosition(fallbackPos: Vector3)
	if not fallbackPos then
		return false
	end
	local classType = self.Owner.ClassType

	if classType == "HumanNPC" then
		if not self.Owner:IsLegless() then
			self.AI:ChangeWalkSpeed(HumanConstants.SPRINT_SPEED)
		end
	elseif classType == "Animal" then
		self.AI:ChangeWalkSpeed(self.Owner.AttackRunSpeed)
	end
	self.AI:PathFindTo(fallbackPos)

	return true
end

function Fallback:AimNPCTowards(ownerClass, targetPos: Vector3, target, eyeTarget: MeshPart?)
	if not targetPos or not ownerClass or not target or not eyeTarget then
		return false
	end

	local done = nil
	local classType = self.Owner.ClassType

	if classType == "HumanNPC" then
		done = ownerClass:AimRightArmTowards(targetPos)
	elseif classType == "Animal" then
		done = ownerClass:SetFlattenedTorsoAimer(CFrame.new(targetPos))
	end

	if done then
		-- 3.2. Can we see the target?
		local isInLineOfSight = AI.IsTargetInView(self.AI, eyeTarget.Position, target, true)

		-- 4. If so, transition to attack state, else seek
		if isInLineOfSight and not CollectionService:HasTag(target, "Dead") then
			self.Machine:Transition(self.AI.AttackState.Name, { Target = target })
		else
			warn("Can't see target falling back, SEEKIN")
			self.Machine:Transition("Seek", { Target = target })
		end
	end

	return true
end

function Fallback:PathFindToFallbackPosition(human: HumanNPC | Animal, target, targetPos: Vector3?)
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		warn("arrived fallback pos")
		-- get updated target position

		if not success then
			self.Machine:Transition("Seek", { Target = target })
			return
		end

		-- 3.1 Aim at target
		if self.Owner.ClassType == "HumanNPC" then
			local NPCAimArm = if human
					and human.BodyParts
					and human.BodyParts["RightUpperArm"]
				then human.BodyParts["RightUpperArm"]
				else nil

			if not NPCAimArm then
				warn("Right arm missing, NPC probably dead")
				return
			end
			-- 3.1. Aim arm & torso towards last seen pos and wait until finished rotating
			targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
			local aimedAt = self:AimNPCTowards(human, targetPos, target, NPCAimArm)

			if not aimedAt then
				self.Machine:Transition("Seek", { Target = target })
				return
			end
		elseif self.Owner.ClassType == "Animal" then
			local aimedAt = self:AimNPCTowards(human, targetPos, target, self.Owner.BodyParts["Head"])

			if not aimedAt then
				self.Machine:Transition("Seek", { Target = target })
				return
			end
			--self.AI:OrientTowards(target:GetPivot().Position)
		end
	end))

	self.Janitor:Add(self.AI.NoobPath.Trapped:Connect(function(trapType: string)
		warn(`NPC pathfind stuck: {trapType}`)
		self.Machine:Transition("Seek", { Target = target })
		return
	end))
	self.Janitor:Add(self.AI.NoobPath.Error:Connect(function(errorType: string)
		warn(`NPC pathfind error: {errorType}`)
		self.Machine:Transition("Seek", { Target = target })
		return
	end))
end

function Fallback:StopReloading(human: HumanNPC)
	local currentGun = human.Inventory:GetGun()
	if currentGun then
		currentGun:StopReloading()
	end
end

function Fallback:Enter(previous, fallbackData)
	warn(`{self.Owner.Name} Entered Fallback from {previous}`)
	while self.Owner.IsRagdolled do
		task.wait(1)
	end

	-- Variables
	local owner = self.Owner
	local target = fallbackData.Target

	if not target then
		error("Fallback state missing target!")
	end
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

	if owner.ClassType == "HumanNPC" then
		self:StopReloading(owner)

		ServerSoundHandler:Play3DNPCVoiceline(
			nil,
			`RangedAIBackOff{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
			self.Owner.VoicelineSound,
			{ MaxDistance = 100 }
		)
	end

	-- 1. Find a suitable position around player to go to
	local hasFallbackPos = self:FindFallbackPosition(owner, target)

	if not hasFallbackPos then
		return
	end

	-- 2. Position found, run and move there
	self:MoveToFallbackPosition(hasFallbackPos)

	-- 3. Wait for NPC to arrive at destination
	self:PathFindToFallbackPosition(owner, target, targetPos)
end

function Fallback:CanTransition(toStateName: string)
	if toStateName == "Patrol" then
		return false
	end

	return true
end

function Fallback:Exit(nextState) end

return Fallback
