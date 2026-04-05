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
	warn("Entered RangeAttack from", previous)
	self.AI:StateChangeReset()
	self.Human:ToggleRightArmAimer(true)
	self.Human:ToggleTorsoAimer(true)
	self.Target = target

	self.Machine:Start()
end

function RangeAttack:Update(dt)
	local now = os.clock()
	local lastAttacked = now - self.LastAttacked
	local human = self.Human
	local ai = self.AI

	if lastAttacked <= self.AI.AttackCooldown then
		return
	end

	if ai.CurrentlyMoving then
		return
	end

	self.LastAttacked = now
	local target = self.Target

	-- this should transition to patrol if target is dead, so further code shouldnt be executed
	AISignals.HandleTargetDead:Fire(self.AI, target)

	-- target is valid
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
	local targetDir = if target:IsA("Model")
		then target.HumanoidRootPart.AssemblyLinearVelocity.Unit
		else target.AssemblyLinearVelocity.Unit

	local NPCAimArm = if human
			and human.BodyParts
			and human.BodyParts["RightUpperArm"]
		then human.BodyParts["RightUpperArm"]
		else nil

	if not NPCAimArm then
		warn("Right arm missing, NPC probably dead")
		return
	end

	-- 1. Check if in shooting range, will move within range if a valid point was found
	ai:CorrectRangePosition(target, targetPos, targetDir)

	human:AimRightArmTowards(target)
	task.wait(0.5)
	local isInLineOfSight = AI.IsTargetInView(ai, NPCAimArm.Position, target, true)

	-- 2. Seek state if not in LOS
	if not isInLineOfSight then
		print("Not in LOS, seeking")
		self.Machine:Transition("Seek", { ShotPosition = targetPos, TargetDirection = targetDir })
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
