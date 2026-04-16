local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local Fallback = setmetatable({}, BaseState)
Fallback.__index = Fallback

function Fallback.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Fallback)
	return self
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

	-- Disable reload if we're reloading & play voiceline
	human.CurrentGun.Reloading = false
	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAIBackOff{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)

	-- 1. Find a suitable position around player to go to
	local randomDistWithinRange = RandomModule.GetRandomIntBetween(self.AI.MinAttackDistance, self.AI.MaxAttackDistance)
	print(randomDistWithinRange)
	local safePos = self.AI:FindAnglePosition(human.HRP.Position, target, nil, randomDistWithinRange, false)

	-- 1.1 (TERMINATION) If we can't find a fallback position, got to attack state (shoots at current position)
	if not safePos then
		warn("Cornered, shoot from current position, ignoring distance requirements")
		self.Machine:Transition(self.AI.AttackStateName, { Target = target, Cornered = true })
		return
	end

	-- 2. Position found, run and move there
	if not self.Human.Legless then
		self.AI:ChangeWalkSpeed(HumanConstants.SPRINT_SPEED)
	end
	self.AI:PathFindTo(safePos)

	-- 3. Wait for NPC to arrive at destination
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		warn("arrived fallback pos")
		-- get updated target position

		if not success then
			self.Machine:Transition("Seek", { Target = target })
			return
		end
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
		local done = human:AimRightArmTowards(targetPos)

		if done then
			-- 3.2. Can we see the target?
			local isInLineOfSight = AI.IsTargetInView(self.AI, NPCAimArm.Position, target, true)

			-- 4. If so, transition to attack state, else seek
			if isInLineOfSight and not CollectionService:HasTag(target, "Dead") then
				self.Machine:Transition(self.AI.AttackStateName, { Target = target })
			else
				self.Machine:Transition("Seek", { Target = target })
			end
		else
			self.Machine:Transition("Seek", { Target = target })
		end
	end))
end

function Fallback:CanTransition(toStateName: string)
	if toStateName == "Patrol" then
		return false
	end

	return true
end

function Fallback:Exit(nextState)
	self.AI:ChangeWalkSpeed(HumanConstants.WALKSPEED)
end

return Fallback
