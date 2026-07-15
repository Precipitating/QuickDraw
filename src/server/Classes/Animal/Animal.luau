local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimalAI = require(ServerScriptService.Server.Classes.AIBehaviour.AnimalAI)
local AnimalData = require(script.Parent.AnimalData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Animal = {}
Animal.__index = Animal

function Animal.new(model: Model?, type: string)
	local self = setmetatable({}, Animal)
	assert(model, "Missing animal model")
	assert(type, "Missing animal type")
	local animalData = AnimalData[type]
	if not animalData then
		warn("Animal type does not exist!")
		return
	end

	self.Character = model
	self.Name = model.Name
	self.Janitor = Janitor.new()
	self.IsRagdolled = false
	self.Health = animalData.Health
	self.Target = workspace:FindFirstChild("Target")
	self.ClassType = "Animal"
	self.Type = type
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.HRP = model:FindFirstChild("HumanoidRootPart")
	self.BodyParts = {
		Head = Utility.GetInstance(model, false, "Head"),
		Body = Utility.GetInstance(model, false, "Body"),
	}
	self.TorsoAimer = self:InitializeTorsoAimer()
	self.AttackRunSpeed = animalData.AttackRunSpeed

	self.AI = AnimalAI.new(self, type)
	self.VoicelineSound = self:SetupVoicelineSound()
	self:Initialize()

	return self
end
function Animal:SetupVoicelineSound()
	local sound = Instance.new("Sound")
	sound.Name = "VoicelineSound"
	sound.Parent = self.HRP
	return sound
end
function Animal:InitializeTorsoAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = self.HRP.RootRigAttachment
	aimer.RigidityEnabled = true
	aimer.AlignType = Enum.AlignType.AllAxes
	aimer.Name = "TorsoAimer"
	aimer.Responsiveness = 150
	aimer.Enabled = false
	aimer.Parent = self.HRP
	return aimer
end

function Animal:ToggleTorsoAimer(enable: boolean)
	local torsoAimer = self.TorsoAimer
	assert(torsoAimer, "[Animal:ToggleTorsoAimer] torsoAimer is nil")
	if torsoAimer.Enabled == enable then
		return
	end

	torsoAimer.Enabled = enable
	torsoAimer.CFrame = CFrame.identity

	--warn(`TorsoAimer new state = {torsoAimer.Enabled}`)
end

--
function Animal:Initialize() end

function Animal:Destroy()
	self.Janitor:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end
return Animal
