local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local BaseState = require(script.Parent.BaseState)

local AnimalAttack = setmetatable({}, BaseState)
AnimalAttack.__index = AnimalAttack

function AnimalAttack.new(machine, ai)
	local self = BaseState.new(machine, ai)
	self.LastAttacked = os.clock()
	self.Target = nil
	self.Cornered = false
	self.LOSLostTime = nil
	setmetatable(self, AnimalAttack)
	return self
end

function AnimalAttack:Enter(previous, targetData: any)
	warn(`[SERVER] {self.Owner.Name} Entered AnimalAttack from {previous}`)
	while self.Owner.IsRagdolled do
		task.wait(1)
	end
	assert(targetData.Target, "[AnimalAttack:Enter] Missing target ")
	self.Target = targetData.Target
	self.Cornered = targetData.Cornered

	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`AnimalAIAttack{self.AI.Type}`,
		self.Owner.VoicelineSound,
		{ MaxDistance = 100, Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
	)

	local target = self.Target
	local ai = self.AI

	ai:Attack(target, function()
		if self:IsTargetDead(target) then
			self.Machine:Transition(self.AI.DefaultState.Name, self.AI.DefaultState.Data)
			return
		end

		if self.Machine and self.Machine.Transition then
			self.Machine:Transition("Seek", { Target = target })
		end
	end)
end

function AnimalAttack:IsTargetDead(target)
	return CollectionService:HasTag(target, "Dead")
end

function AnimalAttack:Exit(nextState) end

return AnimalAttack
