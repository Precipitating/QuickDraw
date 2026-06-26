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

	if not self.Human:IsLegless() then
		self.AI:ChangeWalkSpeed(HumanConstants.SPRINT_SPEED)
	end
	self.AI:PathFindTo(fallbackPos)

	return true
end

function Fallback:AimNPCTowards(human: HumanNPC, targetPos: Vector3, target, NPCAimArm: MeshPart?)
	if not targetPos or not human or not target or not NPCAimArm then
		return false
	end
	local done = human:AimRightArmTowards(targetPos)

	if done then
		-- 3.2. Can we see the target?
		local isInLineOfSight = AI.IsTargetInView(self.AI, NPCAimArm.Position, target, true)

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

function Fallback:PathFindToFallbackPosition(human: HumanNPC, target, targetPos: Vector3?)
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		warn("arrived fallback pos")
		-- get updated target position

		if not success then
			self.Machine:Transition("Seek", { Target = target })
			return
		end

		-- 3.1 Aim and shoot
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
	warn("Entered Fallback from", previous)
	while self.Human.IsRagdolled do
		task.wait(1)
	end
	self.AI:StateChangeReset()

	-- Variables
	local human = self.Human
	local target = fallbackData.Target

	if not target then
		error("Fallback state missing target!")
	end
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

	self:StopReloading(human)

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAIBackOff{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 100 }
	)

	-- 1. Find a suitable position around player to go to
	local hasFallbackPos = self:FindFallbackPosition(human, target)

	if not hasFallbackPos then
		return
	end

	-- 2. Position found, run and move there
	self:MoveToFallbackPosition(hasFallbackPos)

	-- 3. Wait for NPC to arrive at destination
	self:PathFindToFallbackPosition(human, target, targetPos)
end

function Fallback:CanTransition(toStateName: string)
	if toStateName == "Patrol" then
		return false
	end

	return true
end

function Fallback:Exit(nextState) end

return Fallback
