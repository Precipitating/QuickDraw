local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local AnimalAttack = setmetatable({}, BaseState)
AnimalAttack.__index = AnimalAttack

function AnimalAttack.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastAttacked = os.clock()
	self.Target = nil
	self.Cornered = false
	self.LOSLostTime = nil

	setmetatable(self, AnimalAttack)
	return self
end

function AnimalAttack:Enter(previous, targetData: any)
	warn(`[SERVER] {self.Owner.Character.Name} Entered AnimalAttack from {previous}`)
	while self.Owner.IsRagdolled do
		task.wait(1)
	end
	assert(targetData.Target, "[AnimalAttack:Enter] Missing target ")
	self.AI:StateChangeReset()
	self.Target = targetData.Target
	self.Cornered = targetData.Cornered

	-- ServerSoundHandler:Play3DNPCVoiceline(
	-- 	nil,
	-- 	`RangedAIAttack{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
	-- 	self.Owner.VoicelineSound,
	-- 	{ MaxDistance = 100 }
	-- )

	self.Machine:Start()
end

function AnimalAttack:IsTargetDead(target)
	return CollectionService:HasTag(target, "Dead")
end

function AnimalAttack:Update(dt)
	local now = os.clock()
	local lastAttacked = now - self.LastAttacked
	local animal = self.Owner
	local ai = self.AI

	if self.Owner.IsRagdolled then
		self.Owner:ToggleTorsoAimer(false)
		return
	end

	local target = self.Target
	local animalPos = animal.Character:GetPivot().Position
	if self:IsTargetDead(target) then
		self.Machine:Transition(self.AI.DefaultState.Name, self.AI.DefaultState.Data)
		return
	end
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

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

	if lastAttacked <= self.AI.AttackCooldown then
		return
	end
	if not ai.NoobPath.Idle then
		return
	end

	local isInLineOfSight = AI.IsTargetInView(ai, animalPos, target, true)

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

	ai:OrientTowards(self.Target:GetPivot().Position)
	self.LastAttacked = now
	ai:Attack()
end

function AnimalAttack:Exit(nextState)
	self.Machine:Stop()
end

return AnimalAttack
