local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PatrolData = ServerStorage.PatrolData
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local BaseState = require(script.Parent.BaseState)

local Patrol = setmetatable({}, BaseState)
Patrol.__index = Patrol

function Patrol.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Patrol)
	self.PatrolData = nil
	self.PatrolStayTime = ai.PatrolStayTime
	self.LastPatrol = os.clock()
	return self
end

function Patrol:Enter(previous, patrolData)
	warn(`[SERVER] {self.Owner.Character.Name} Entered Patrol from {previous}`)
	self.PatrolData = PatrolData[patrolData]
	self.AI:StateChangeReset()
	self.Machine:Start()
end

function Patrol:Update(dt)
	local now = os.clock()
	local timeElapsedSincePatrol = now - self.LastPatrol
	local seenEnemyModel = self.AI:CheckSurroundingsForEnemy()

	if seenEnemyModel then
		if self.Owner.ClassType == "HumanNPC" then
			self.Machine:Transition("RangeAttack", { Target = seenEnemyModel })
		elseif self.Owner.ClassType == "Animal" then
			self.Machine:Transition("AnimalAttack", { Target = seenEnemyModel })
		end
		return
	end

	if self.Owner.IsRagdolled then
		return
	end

	if timeElapsedSincePatrol < self.PatrolStayTime then
		return
	end
	if not self.AI.NoobPath.Idle or self.AI.NoobPath.InAir then
		return
	end

	local ai = self.AI
	self.LastPatrol = now
	local patrolData = self.PatrolData

	local patrolFolder = patrolData:GetChildren()
	local wayPoint = patrolFolder[RandomModule.GetRandomIntBetween(1, #patrolFolder)]
	local wayPointPos = wayPoint.Position
	ai:PathFindTo(wayPointPos)
end

function Patrol:Exit(nextState)
	self.Machine:Stop()
end

return Patrol
