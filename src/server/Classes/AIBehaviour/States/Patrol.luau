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
	warn("Entered Patrol from", previous)
	self.PatrolData = PatrolData[patrolData]
	self.AI:StateChangeReset()
	self.Machine:Start()
end

function Patrol:Update(dt)
	local now = os.clock()
	local timeElapsedSincePatrol = now - self.LastPatrol
	local seenEnemyModel = self.AI:CheckSurroundingsForEnemy()

	if seenEnemyModel then
		self.Machine:Transition("RangeAttack", { Target = seenEnemyModel })
		return
	end

	if self.Human.IsRagdolled then
		return
	end

	if timeElapsedSincePatrol < self.PatrolStayTime then
		return
	end
	if self.AI.CurrentlyMoving then
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
