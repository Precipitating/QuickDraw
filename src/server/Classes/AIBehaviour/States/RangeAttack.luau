local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local RangeAttack = setmetatable({}, BaseState)
RangeAttack.__index = RangeAttack

function RangeAttack.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastAttacked = os.clock()
	self.Target = nil
	self.Cornered = false
	self.LOSLostTime = nil

	setmetatable(self, RangeAttack)
	return self
end

function RangeAttack:Enter(previous, targetData: any)
	warn(`[SERVER] {self.Owner.Name} Entered RangeAttack from {previous}`)
	while self.Owner.IsRagdolled do
		task.wait(1)
	end
	assert(targetData.Target, "[RangeAttack:Enter] Missing target ")
	self.Target = targetData.Target
	self.Cornered = targetData.Cornered

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAIAttack{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
		self.Owner.VoicelineSound,
		{ MaxDistance = 100 }
	)

	self.Machine:Start()
end

function RangeAttack:IsTargetDead(target)
	return CollectionService:HasTag(target, "Dead")
end

function RangeAttack:Update(dt)
	local now = os.clock()
	local lastAttacked = now - self.LastAttacked
	local human = self.Owner
	local ai = self.AI

	if self.Owner.IsRagdolled then
		self.Owner:ToggleTorsoAimer(false)
		return
	end

	local target = self.Target
	if self:IsTargetDead(target) then
		self.Machine:Transition(self.AI.DefaultState.Name, self.AI.DefaultState.Data)
		return
	end
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
	local inRange = ai:CorrectRangePosition(targetPos)
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

	if lastAttacked <= self.AI.AttackCooldown then
		return
	end
	if not ai.NoobPath.Idle then
		return
	end

	local isInLineOfSight = AI.IsTargetInView(ai, NPCAimArm.Position, target, true)

	-- 2. Seek state if not in LOS (with patience timer)
	if not isInLineOfSight then
		self.LOSLostTime = self.LOSLostTime or os.clock()
		if os.clock() - self.LOSLostTime > 2 then
			self.LOSLostTime = nil
			self.Machine:Transition("Seek", { Target = target })
		end
		return
	else
		self.LOSLostTime = nil
	end

	if self.Owner.Inventory:GetThrowable() and ai:ThrowThrowable(targetPos) then
		return
	end
	human:AimRightArmTowards(target)
	self.LastAttacked = now
	ai:Attack()
end

function RangeAttack:Exit(nextState) end

return RangeAttack
