local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local AISignals = require(ServerScriptService.Server.Classes.AIBehaviour.AISignals)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local Seek = setmetatable({}, BaseState)
Seek.__index = Seek

function Seek.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Seek)
	self.LastChecked = os.clock()
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

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAITooFar{RandomModule.GetRandomIntBetween(1, 3)}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)
	-- move to last seen position
	ai:PathFindTo(seekPosition)

	AISignals.PathfindComplete:Once(function()
		if not self.Human then
			return
		end
		-- have a look around 4 directions for any enemies
		self.Human:ToggleTorsoAimer(true)
		local foundEnemy = ai:LookAround(seekDir)
		if foundEnemy then
			self.Machine:Transition(self.AI.AttackStateName, foundEnemy)
		else
			ServerSoundHandler:Play3DNPCVoiceline(
				nil,
				"RangedAILostSight1",
				self.Human.VoicelineSound,
				{ MaxDistance = 200 }
			)
			self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		end
		return
	end)
	self.Machine:Start()
end

-- Check for enemy during pathfind
function Seek:Update(dt)
	local ai = self.AI
	local now = os.clock()
	if now - self.LastChecked < 1 then
		return
	end

	if self.Human.IsRagdolled then
		return
	end

	self.LastChecked = now
	local foundEnemy = ai:CheckSurroundingsForEnemy()
	if foundEnemy then
		self.Machine:Transition(self.AI.AttackStateName, foundEnemy)
		return
	end
end

function Seek:Exit(nextState)
	self.Human.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
	self.Machine:Stop()
end

return Seek
