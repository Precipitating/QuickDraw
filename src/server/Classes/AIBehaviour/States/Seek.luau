local ServerScriptService = game:GetService("ServerScriptService")
local AISignals = require(ServerScriptService.Server.Classes.AIBehaviour.AISignals)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local BaseState = require(script.Parent.BaseState)

local Seek = setmetatable({}, BaseState)
Seek.__index = Seek

function Seek.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Seek)
	return self
end

function Seek:Enter(previous)
	print("Entered Seek from", previous)

	if not self.Machine.LastSeenTargetPosition then
		self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		return
	end

	local ai = self.AI
	local legless = self.Human.Legless
	local humanoid = self.Human.Humanoid
	ai:StateChangeReset()

	if not legless then
		humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
	end

	-- move to last seen position
	ai:PathFindTo(self.Machine.LastSeenTargetPosition)

	AISignals.PathfindComplete:Wait()

	self.Machine.LastSeenTargetPosition = nil

	-- have a look around 4 directions for any enemies
	local foundEnemy = ai:LookAround()
	if foundEnemy then
		self.Machine:Transition(self.AI.AttackStateName, foundEnemy)
		return
	else
		self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
	end
end

function Seek:Exit(nextState)
	print("Leaving Seek to", nextState)
	self.Human.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
end

return Seek
