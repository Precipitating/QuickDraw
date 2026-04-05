-- inheriting Human and defining Player only data
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationIds = require(ReplicatedStorage.Shared.AnimationData.AnimationIds)
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local RangeAI = require(ServerScriptService.Server.Classes.AIBehaviour.RangeAI)
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local Human = require(script.Parent.Human)
local HumanConstants = require(script.Parent.HumanConstants)

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	Human.AssignBodyParts(self, "NPC")
	self.CurrentGun = Gun.new("Winchester", self, self.Character)
	self.CurrentThrowable = Throwable.new("Dynamite", self)
	self.HumanType = "NPC"
	self.RightArmAimer = self:InitializeRightArmAimer()
	self.TorsoAimer = self:InitializeTorsoAimer()
	self.CurrentGun:AddGunToInventory()
	self.CurrentThrowable:AddThrowableToInventory()
	self.CurrentTrack = nil
	self.AI = RangeAI.new(self)
	self.NoiseSeed = RandomModule.GetRandom() * 1000

	self:SetNPCNetworkOwnership()
	self:SetWeaponCollisions()

	humanoid.WalkSpeed = HumanConstants.WALKSPEED
	print(`New human class initiated for NPC {self.Character.Name}`)
	return self :: any
end

function HumanNPC:LoadServerAnimationTracks() end

function HumanNPC:SetNPCNetworkOwnership()
	for _, part in self.BodyParts do
		part:SetNetworkOwner(nil)
	end
end

function HumanNPC:SetWeaponCollisions()
	for _, part in self.CurrentGun.Tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "NPC"
		end
	end
end
function HumanNPC:InitializeRightArmAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local rightArm = self.BodyParts["RightUpperArm"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = rightArm:WaitForChild("RightShoulderAttachment")
	aimer.RigidityEnabled = false
	aimer.Name = "RightArmAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 50
	aimer.Enabled = false
	aimer.Parent = rightArm
	return aimer
end
function HumanNPC:InitializeTorsoAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local upperTorso = self.BodyParts["UpperTorso"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = upperTorso:WaitForChild("WaistRigAttachment")
	aimer.RigidityEnabled = true
	aimer.AlignType = Enum.AlignType.AllAxes
	aimer.Name = "TorsoAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 150
	aimer.Enabled = false
	aimer.Parent = upperTorso
	return aimer
end

function HumanNPC:ToggleRightArmAimer(enable: boolean)
	local rightArmOrientator = self.RightArmAimer

	assert(rightArmOrientator, "[HumanNPC:ToggleRightArmAimer] RightArmAimer is nil")

	if enable then
		rightArmOrientator.Enabled = true
	else
		rightArmOrientator.Enabled = false
	end
end

function HumanNPC:SetCrawlState()
	if self.Dead then
		return
	end
	local parts = self.DisabledBodyParts

	if (parts["LeftUpperLeg"] or parts["LeftLowerLeg"]) and (parts["RightUpperLeg"] or parts["RightLowerLeg"]) then
		warn("Should be crawling")
		if self.Legless then
			return
		end

		self:Ragdoll(3)

		print("Both legs disabled")

		-- set crawl anims
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		hrp.CanCollide = false

		-- this sets it on client
		AnimationHandler:SetAnimationFolder(nil, "CrawlAnimations", self.Character)

		-- we need to set on server as well, as the body is lying
		local crawlAnim = Instance.new("Animation")

		crawlAnim.AnimationId = `rbxassetid://{AnimationIds.LeglessGunIdle}`
		local track = self.Animator:LoadAnimation(crawlAnim)
		track:Play()

		self.Humanoid.UseJumpPower = true
		self.Humanoid.JumpPower = 0
		self.Humanoid.WalkSpeed = 8

		self:FixCrawlADS()

		self.Legless = true

		warn(`{self.Character.Name} should be legless now`)
	end
end
function HumanNPC:ToggleTorsoAimer(enable: boolean)
	local torsoAimer = self.TorsoAimer

	assert(torsoAimer, "[HumanNPC:ToggleTorsoAimer] torsoAimer is nil")

	if self.Legless then
		torsoAimer.Enabled = false
		return
	end

	if enable then
		torsoAimer.Enabled = true
	else
		torsoAimer.Enabled = false
	end

	warn(`TorsoAimer new state = {torsoAimer.Enabled}`)
end

function HumanNPC:AimRightArmTowards(target)
	self:ToggleRightArmAimer(true)
	self:ToggleTorsoAimer(true)
	local rightArm = self.BodyParts["RightUpperArm"]
	local origin = rightArm.Position

	local targetPos = target:IsA("Model") and target:GetPivot().Position or target.Position

	local lookCF = CFrame.lookAt(origin, targetPos)

	-- smooth time-based noise
	local t = os.clock() * HumanConstants.SWAY_SPEED
	local seed = self.NoiseSeed

	local yawNoise = math.noise(seed, t, 0)
	local pitchNoise = math.noise(seed, 0, t)

	local swayYaw = yawNoise * HumanConstants.SWAY_AMOUNT
	local swayPitch = pitchNoise * HumanConstants.SWAY_AMOUNT

	lookCF *= CFrame.Angles(math.rad(90) + swayPitch, swayYaw, 0)

	self.RightArmAimer.CFrame = lookCF

	local flattenedLookAt = Vector3.new(targetPos.X, self.HRP.Position.Y, targetPos.Z)
	self.TorsoAimer.CFrame = CFrame.lookAt(self.HRP.Position, flattenedLookAt)
end

function HumanNPC:Ragdoll(duration: number)
	local humanoid = self.Humanoid
	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	task.delay(duration, function()
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end

	self.Humanoid:EquipTool(gunTool)
end

function HumanNPC:UnEquipCurrentTool()
	self.Humanoid:UnEquipTools()
end

function HumanNPC:OnDeath()
	Debris:AddItem(self.Character, 30)
	self.AI.StateMachine:Transition("Dead")
	Human.OnDeath(self)
end

return HumanNPC
