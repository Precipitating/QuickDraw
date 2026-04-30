local CollectionService = game:GetService("CollectionService")
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
	self.PredictionAheadTime = 1

	return self
end

-- Uses the target's velocity to predict where they may be
function Seek:PredictTarget(target: Model | BasePart): Vector3
	local currentTargetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position

	local primaryPart = if target:IsA("Model") then target.PrimaryPart else target
	if not primaryPart then
		return currentTargetPos
	end

	local targetVelocity = primaryPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
	if horizontalVelocity.Magnitude < 0.1 then
		return currentTargetPos -- target is stationary, no point predicting
	end

	return currentTargetPos + targetVelocity * self.PredictionAheadTime
end

function Seek:Enter(previous, seekData)
	warn(`[SERVER] {self.Human.Character.Name} Entered Seek from {previous}`)
	self.AI:StateChangeReset()
	if not seekData then
		warn("No last seen target, back to patrol")
		self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
		return
	end

	-- Either player model or a basepart
	local target: Model | BasePart = seekData.Target
	assert(target, "NPC Seek state cannot proceed, target is nil")

	self.Machine:Start()

	local predictedTargetLocation = self:PredictTarget(target)

	local ai = self.AI

	local legless = self.Human.Legless

	if not legless then
		ai:ChangeWalkSpeed(HumanConstants.SPRINT_SPEED)
	end

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAITooFar{RandomModule.GetRandomIntBetween(1, 3)}{self.AI.Type}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)

	-- 1. Move to last seen position OR a valid position around the last seen position (respecting radius and vision)
	local safeSeekPos = ai:FindAnglePosition(
		self.Human.BodyParts["RightUpperArm"].Position,
		target,
		predictedTargetLocation,
		self.AI.MinAttackDistance,
		false
	)
	ai:PathFindTo(safeSeekPos)

	if not self.AI or not self.AI.NoobPath or not self.AI.NoobPath.Reached then
		return
	end
	-- 2. Wait until destination reached
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		if not success then
			warn("Seek pathfind failed, returning to patrol")

			self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
			return
		end
		warn("Reached")
		if not self.Human then
			return
		end

		local foundEnemy = ai:LookAround()
		if foundEnemy and not CollectionService:HasTag(foundEnemy, "Dead") then
			local targetPos = if foundEnemy:IsA("Model") then foundEnemy:GetPivot().Position else foundEnemy.Position
			local inRange = ai:CorrectRangePosition(targetPos)

			if typeof(inRange) == "string" then
				if inRange == "Fallback" then
					self.Machine:Transition("Fallback", { Target = foundEnemy })
					return
				elseif inRange == "Seek" then
					-- Pathfinded but still too far, give up and patrol
					self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
					return
				end
			end

			-- inRange is true, distance is valid
			self.Machine:Transition(self.AI.AttackStateName, { Target = foundEnemy })
		else
			ServerSoundHandler:Play3DNPCVoiceline(
				nil,
				`RangedAILostSight1{self.AI.Type}`,
				self.Human.VoicelineSound,
				{ MaxDistance = 200 }
			)

			self.Machine:Transition("Patrol", self.AI.DefaultPatrolKey)
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
	self.AI.NoobPath:Stop()
end

return Seek
