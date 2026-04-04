local ServerScriptService = game:GetService("ServerScriptService")
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local AISignals = require(ServerScriptService.Server.Classes.AIBehaviour.AISignals)
local BaseState = require(script.Parent.BaseState)

local RangeAttack = setmetatable({}, BaseState)
RangeAttack.__index = RangeAttack

function RangeAttack.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastAttacked = os.clock()
	self.Target = nil
	setmetatable(self, RangeAttack)
	return self
end

function RangeAttack:Enter(previous, target: BasePart | Model)
	print("Entered RangeAttack from", previous)
	self.Target = target

	self.Machine:Start()
end

function RangeAttack:Update(dt)
	local now = os.clock()
	local lastAttacked = now - self.LastAttacked

	if lastAttacked <= self.AI.AttackCooldown then
		return
	end

	self.LastAttacked = now
	local target = self.Target
	local human = self.Human
	local ai = self.AI
	-- this should transition to patrol if target is dead, so further code shouldnt be executed
	AISignals.HandleTargetDead:Fire(self, target)

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

	-- 1. Check if in shooting range, true if still attack state afterwards
	ai:CorrectRangePosition(target, targetPos)

	-- 2. Aim at target
	human:ToggleRightArmAimer(true)
	human:ToggleTorsoAimer(true)
	human:AimRightArmTowards(target)

	local isInLineOfSight = AI.IsTargetInView(ai, NPCAimArm.Position, target, true)

	-- 2.1 Seek state if not in LOS
	if not isInLineOfSight then
		print("Not in LOS, seeking")
		self.Machine:Transition("Seek")
		return
	end

	-- 3. Target in view
	self.Machine.LastSeenTargetPosition = targetPos

	-- 4. Throw nade if possible
	if ai:ThrowThrowable(targetPos) then
		return
	end

	-- 5. SHOOT
	ai:Attack()
end

function RangeAttack:Exit(nextState)
	print("Leaving RangeAttack to", nextState)
	self.Machine:Stop()
end

return RangeAttack
