local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AI = require(ServerScriptService.Server.Classes.AIBehaviour.AI)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local Fallback = setmetatable({}, BaseState)
Fallback.__index = Fallback

function Fallback.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Fallback)
	return self
end

function Fallback:Enter(previous, fallbackData)
	warn("Entered Fallback from", previous)
	while self.Human.IsRagdolled do
		task.wait(1)
	end
	self.AI:StateChangeReset()

	-- Variables
	local human = self.Human
	local target = fallbackData.Target

	if not target then
		error("Fallback state missing target!")
	end
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
	local targetDir = if target:IsA("Model")
		then target.HumanoidRootPart.AssemblyLinearVelocity.Unit
		else target.AssemblyLinearVelocity.Unit

	-- Disable reload if we're reloading & play voiceline
	human.CurrentGun.Reloading = false
	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`RangedAIBackOff{RandomModule.GetRandomIntBetween(1, 3)}`,
		self.Human.VoicelineSound,
		{ MaxDistance = 200 }
	)

	-- 1. Find a suitable position around player to go to
	local halfDist = self.AI.MaxAttackDistance * 0.5
	local safePos = self.AI:FindAnglePosition(human.HRP.Position, target, halfDist or 50, false)

	-- 1.1 (TERMINATION) If we can't find a fallback position, got to attack state (shoots at current position)
	if not safePos then
		self.Machine:Transition(self.AI.AttackStateName, { Target = target, Cornered = true })
		return
	end

	-- 2. Position found, run and move there
	if not self.Human.Legless then
		human.Humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
	end
	self.AI:PathFindTo(safePos)

	-- 3. Wait for NPC to arrive at destination (if possible)
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		local NPCAimArm = if human
				and human.BodyParts
				and human.BodyParts["RightUpperArm"]
			then human.BodyParts["RightUpperArm"]
			else nil

		-- 3.1. Aim arm & torso towards last seen pos and wait until finished rotating
		human:AimRightArmTowards(targetPos)

		-- 3.2. Can we see the target?
		local isInLineOfSight = AI.IsTargetInView(self.AI, NPCAimArm.Position, target, true)

		-- 4. If so, transition to attack state, else seek
		if isInLineOfSight then
			self.Machine:Transition(self.AI.AttackStateName, { Target = target })
		else
			self.Machine:Transition("Seek", { ShotPosition = targetPos, TargetDirection = targetDir })
		end
	end))
end

function Fallback:Exit(nextState)
	self.Human.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
end

return Fallback
