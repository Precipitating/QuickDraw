local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local AISignals = require(ServerScriptService.Server.Classes.AIBehaviour.AISignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local RangeAttack = setmetatable({}, BaseState)
RangeAttack.__index = RangeAttack

function RangeAttack.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastAttacked = os.clock()
	self.Target = nil
	self.Cornered = false
	setmetatable(self, RangeAttack)
	return self
end

function RangeAttack:Enter(previous, targetData: any)
	warn("Entered RangeAttack from", previous)
	while self.Human.IsRagdolled do
		task.wait(1)
	end
	self.AI:StateChangeReset()
	assert(targetData.Target, "[RangeAttack:Enter] Missing target ")
	self.Target = targetData.Target
	self.Cornered = targetData.Cornered

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAIAttack{RandomModule.GetRandomIntBetween(1, 3)}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)

	self.Machine:Start()
end

function RangeAttack:IsTargetDead(target)
	return CollectionService:HasTag(target, "Dead")
end

function RangeAttack:Update(dt)
	local now = os.clock()
	local lastAttacked = now - self.LastAttacked
	local human = self.Human
	local ai = self.AI

	if lastAttacked <= self.AI.AttackCooldown then
		return
	end

	if not ai.NoobPath.Idle then
		return
	end

	if self.Human.IsRagdolled then
		self.Human:ToggleTorsoAimer(false)
		return
	end

	self.LastAttacked = now
	local target = self.Target

	-- this should transition to patrol if target is dead, so further code shouldnt be executed
	if self:IsTargetDead(target) then
		self.Machine:Transition(self.AI.DefaultState.Name, self.AI.DefaultState.Data)
		return
	end
	-- target is valid
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

	local NPCAimArm = if human
			and human.BodyParts
			and human.BodyParts["RightUpperArm"]
		then human.BodyParts["RightUpperArm"]
		else nil

	if not NPCAimArm then
		warn("Right arm missing, NPC probably dead")
		return
	end

	-- 1. Check if in shooting range, will move within range if inRange is true
	local inRange = ai:CorrectRangePosition(targetPos)

	-- if seek, target too far away, fallback means too target is too close
	if inRange and typeof(inRange) == "string" then
		if inRange == "Seek" then
			self.Machine:Transition("Seek", { Target = target })
			return
		elseif inRange == "Fallback" and not self.Cornered then
			self.Machine:Transition("Fallback", { Target = target })
			return
		end
	end

	human:AimRightArmTowards(target)
	local isInLineOfSight = AI.IsTargetInView(ai, NPCAimArm.Position, target, true)

	-- 2. Seek state if not in LOS
	if not isInLineOfSight then
		print("Not in LOS, seeking")
		self.Machine:Transition("Seek", { Target = target })
		return
	end

	-- 3. Throw nade if possible
	if ai:ThrowThrowable(targetPos) then
		return
	end

	-- 4 Aim at target
	human:AimRightArmTowards(target)

	-- 5. SHOOT
	ai:Attack()
end

function RangeAttack:Exit(nextState)
	self.Machine:Stop()
end

return RangeAttack
