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

function Seek:Enter(previous, seekPos)
	warn("Entered Seek from", previous)
	self.AI:StateChangeReset()
	if not seekPos then
		warn("No last seen target, back to patrol")
		self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		return
	end

	local seekPosition = seekPos.ShotPosition
	local seekDir = seekPos.TargetDirection

	local ai = self.AI
	local legless = self.Human.Legless
	local humanoid = self.Human.Humanoid

	if not legless then
		humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
	end

	-- move to last seen position
	ai:PathFindTo(seekPosition)

	self.Connections["PathfindComplete"] = AISignals.PathfindComplete:Connect(function()
		-- have a look around 4 directions for any enemies
		local foundEnemy = ai:LookAround(seekDir)
		if foundEnemy then
			self.Machine:Transition(self.AI.AttackStateName, foundEnemy)
			return
		else
			self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		end
	end)
end

function Seek:Exit(nextState)
	self.Human.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
end

return Seek
