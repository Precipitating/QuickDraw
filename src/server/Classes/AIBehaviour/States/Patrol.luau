local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PatrolData = require(ServerScriptService.Server.Classes.AIBehaviour.PatrolData)
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
	print("Entered Patrol from", previous)
	local ai = self.AI
	self.PatrolData = PatrolData[patrolData]
	ai:StateChangeReset()
	self.Machine:Start()
end

function Patrol:Update(dt)
	local now = os.clock()
	local timeElapsedSincePatrol = now - self.LastPatrol
	local seenEnemyModel = self.AI:CheckSurroundingsForEnemy()

	if seenEnemyModel then
		self.Machine:Transition("RangeAttack", seenEnemyModel)
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

	ai:PathFindTo(patrolData[RandomModule.GetRandomIntBetween(1, #patrolData)])
end

function Patrol:Exit(nextState)
	self.Machine:Stop()
	print("Leaving Patrol to", nextState)
end

return Patrol
