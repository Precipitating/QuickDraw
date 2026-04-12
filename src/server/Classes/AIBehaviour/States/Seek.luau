local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
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

function Seek:Enter(previous, seekData)
	warn("Entered Seek from", previous)
	self.AI:StateChangeReset()
	if not seekData then
		warn("No last seen target, back to patrol")
		self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		return
	end

	-- Either player model or a basepart
	local target = seekData.Target
	assert(target, "NPC Seek state cannot proceed, target is nil")
	local currentTargetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

	local ai = self.AI
	local legless = self.Human.Legless

	if not legless then
		ai:ChangeWalkSpeed(HumanConstants.SPRINT_SPEED)
	end

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAITooFar{RandomModule.GetRandomIntBetween(1, 3)}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)

	-- 1. Move to last seen position OR a valid position around the last seen position (respecting radius)
	local safeSeekPos = ai:FindAnglePosition(self.Human.HRP.Position, target, self.AI.MinAttackDistance or 50, false)

	if not safeSeekPos then
		ai:PathFindTo(currentTargetPos)
	else
		ai:PathFindTo(safeSeekPos)
	end
	self.Machine:Start()

	-- 2. Wait until destination reached
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		if success then
			warn("Reached")
			if not self.Human then
				return
			end

			-- 2.1 Have a look around 4 directions for any enemies
			local foundEnemy = ai:LookAround()

			-- 2.2 If enemy spotted
			if foundEnemy then
				local targetPos = if foundEnemy:IsA("Model")
					then foundEnemy:GetPivot().Position
					else foundEnemy.Position

				-- 2.2.1 Fall back if too close
				local inRange = ai:CorrectRangePosition(targetPos)
				if inRange and typeof(inRange) == "string" then
					if inRange == "Fallback" then
						self.Machine:Transition("Fallback", { Target = foundEnemy })
						return
					end
				end
				-- Else Attack state
				self.Machine:Transition(self.AI.AttackStateName, { Target = foundEnemy })
			else
				-- If not enemy spotted, lost them.
				ServerSoundHandler:Play3DNPCVoiceline(
					nil,
					"RangedAILostSight1",
					self.Human.VoicelineSound,
					{ MaxDistance = 200 }
				)
				self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
			end
			return
		end
	end))
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
		self.Machine:Transition(self.AI.AttackStateName, { Target = foundEnemy })
		return
	end
end

function Seek:Exit(nextState)
	self.AI:ChangeWalkSpeed(HumanConstants.WALKSPEED)
	self.Machine:Stop()
end

return Seek
