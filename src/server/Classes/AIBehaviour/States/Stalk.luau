local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local Stalk = setmetatable({}, BaseState)
Stalk.__index = Stalk
-- Always know the player's location and go there
function Stalk.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastChecked = os.clock()
	setmetatable(self, Stalk)

	return self
end

function Stalk:MoveToTarget(target)
	--Move target's position at safe dist
	local ai = self.AI

	local safeStalkPos = ai:FindAnglePosition(
		self.Human.BodyParts["RightUpperArm"].Position,
		target,
		if target:IsA("Model") then target:GetPivot().Position else target.Position,
		self.AI.MinAttackDistance,
		false
	)
	ai:PathFindTo(safeStalkPos)
end

function Stalk:Enter(previous, StalkData)
	warn(`[SERVER] {self.Human.Character.Name} Entered Stalk from {previous}`)
	self.AI:StateChangeReset()
	if not StalkData then
		warn("No target data, dying")
		self.Human:Die(nil)
		return
	end

	-- Either player model or a basepart
	local target: Model | BasePart = StalkData.Target
	assert(target, "NPC Stalk state cannot proceed, target is nil")

	self.Machine:Start()

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

	-- 1.
	self:MoveToTarget(target)

	if not self.AI or not self.AI.NoobPath or not self.AI.NoobPath.Reached then
		return
	end
	-- 2. Wait until destination reached
	self.Janitor:Add(self.AI.NoobPath.Reached:Connect(function(success: boolean)
		if not self.Human then
			return
		end
		if not success then
			warn("Stalk pathfind failed, trying again")
			Stalk:MoveToTarget(target)
			return
		end
		warn("Reached")

		if target and not CollectionService:HasTag(target, "Dead") then
			local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
			local inRange = ai:CorrectRangePosition(targetPos)

			if typeof(inRange) == "string" then
				Stalk:MoveToTarget(target)
				return
			end
		else
			self.Human:Die(nil)
		end
	end))
end

-- Check for enemy during pathfind
function Stalk:Update(dt)
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
		self.Machine:Transition(self.AI.AttackState.Name, { Target = foundEnemy })
		return
	end
end

function Stalk:Exit(nextState)
	self.AI:ChangeWalkSpeed(HumanConstants.WALKSPEED)
	self.Machine:Stop()
	self.AI.NoobPath:Stop()
end

return Stalk
