-- inheriting Human and defining Player only data
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationIds = require(ReplicatedStorage.Shared.AnimationData.AnimationIds)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local AwardHandler = require(ServerScriptService.Server.AwardHandler.AwardHandler)

local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local RangeAI = require(ServerScriptService.Server.Classes.AIBehaviour.RangeAI)
local Human = require(script.Parent.Human)

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid, classType: string, optionalData: any?)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	Human.AssignBodyParts(self, "NPC")
	self:SetupBloodEmitters()
	self.ClassType = "HumanNPC"
	self.HumanType = "NPC"
	self.RightArmAimer = self:InitializeRightArmAimer()
	self.TorsoAimer = self:InitializeTorsoAimer()
	self.AI = RangeAI.new(self, classType, optionalData)
	self.CurrentTrack = nil
	self.NoiseSeed = RandomModule.GetRandom() * 1000
	self.VoicelineSound = self:SetupVoicelineSound()

	self:SetNPCNetworkOwnership()
	self:InitializeWeaponLoadout()
	if self.Inventory:GetGun() then
		self:SetWeaponCollisions()
	end

	self.AI:ChangeWalkSpeed(HumanConstants.WALKSPEED)

	if self.Character:GetAttribute("DefaultStateData") then
	end

	self:SetInvincibleFor(HumanConstants.ON_SPAWN_INVICIBILITY_TIME, true)

	warn(`[SERVER] New human class initiated for NPC {self.Character.Name}`)
	return self :: any
end

function HumanNPC:InitializeWeaponLoadout()
	if self.AI.WeaponName then
		self.Inventory:AddWeaponToInventory(self.AI.WeaponName)
		self.Inventory:EquipWeapon("Gun")
	end

	if self.AI.ThrowableName then
		self.Inventory:AddWeaponToInventory(self.AI.ThrowableName, self.AI.ThrowableAmmo, self.AI.MaxThrowableAmmo)
	end
end

function HumanNPC:SetupVoicelineSound()
	local sound = Instance.new("Sound")
	sound.Name = "VoicelineSound"
	sound.Parent = self.HRP
	return sound
end

function HumanNPC:SetNPCNetworkOwnership()
	for _, part in self.BodyParts do
		part:SetNetworkOwner(nil)
	end
end

function HumanNPC:SetWeaponCollisions()
	for _, part in self.Inventory:GetGun().Tool:GetDescendants() do
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
	aimer.RigidityEnabled = true
	aimer.Name = "RightArmAimer"
	aimer.Responsiveness = 70
	aimer.Enabled = false
	aimer.Parent = rightArm
	return aimer
end
function HumanNPC:InitializeTorsoAimer()
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

function HumanNPC:ToggleRightArmAimer(enable: boolean)
	local rightArmOrientator = self.RightArmAimer
	assert(rightArmOrientator, "[HumanNPC:ToggleRightArmAimer] RightArmAimer is nil")
	if rightArmOrientator.Enabled == enable then
		return
	end

	rightArmOrientator.Enabled = enable
	rightArmOrientator.CFrame = CFrame.identity
end

function HumanNPC:OnHit(damage: number, damageMultiplier: number, limbName: string, shooter: Player | Model)
	Human.OnHit(self, damage, damageMultiplier, limbName, shooter)

	-- If sheriff is hit by player, make them an enemy to the sheriff
	local isShooterPlayer = if typeof(shooter) == "Instance" and shooter:IsA("Player") then shooter else nil
	if CollectionService:HasTag(self.Character, "Sheriff") and isShooterPlayer then
		local shooterCharacter = isShooterPlayer.Character
		if shooterCharacter then
			CollectionService:AddTag(shooterCharacter, "Wanted")
		end
	end
end
function HumanNPC:RevertCrawlState()
	if not self:isLegless() then
		return
	end

	-- Stop any server-side crawl animations
	for _, track in ipairs(self.Animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	-- Revert animation folder back to default on client
	AnimationHandler:ResetToDefaultAnimations(self.Character)
	--AnimationHandler:SetAnimationFolder(nil, "DefaultAnimations", self.Character)

	-- Re-enable HRP collision
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CanCollide = true
	end

	-- Restore jump and walk speed
	self.Humanoid.UseJumpPower = false
	self.AI:ChangeWalkSpeed(HumanConstants.WALKSPEED)

	local currentGun = self.Inventory:GetGun()

	if currentGun then
		currentGun:ToggleCollision(true)
	end

	self:UpdateLeglessState(false)
end

function HumanNPC:SetCrawlState()
	if self.Dead then
		return
	end
	local parts = self.DisabledBodyParts

	if self:IsLegless() then
		return
	end

	local currentGun = self.Inventory:GetGun()
	if currentGun then
		currentGun:ToggleCollision(false)
	end

	if (parts["LeftUpperLeg"] or parts["LeftLowerLeg"]) and (parts["RightUpperLeg"] or parts["RightLowerLeg"]) then
		warn("Should be crawling")

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
		self.AI:ChangeWalkSpeed(HumanConstants.CRAWL_SPEED)

		self:FixCrawlADS()

		self:UpdateLeglessState(true)

		warn(`{self.Character.Name} should be legless now`)
	end
end
function HumanNPC:ToggleTorsoAimer(enable: boolean)
	local torsoAimer = self.TorsoAimer
	assert(torsoAimer, "[HumanNPC:ToggleTorsoAimer] torsoAimer is nil")
	if torsoAimer.Enabled == enable then
		return
	end

	torsoAimer.Enabled = enable

	if not enable then
		torsoAimer.CFrame = CFrame.identity
	end

	--warn(`TorsoAimer new state = {torsoAimer.Enabled}`)
end
function HumanNPC:AimRightArmTowards(target)
	-- 1. Early exits & Guard rails
	if self.DisabledBodyParts["RightUpperArm"] then
		return false
	end

	local rightArm = self.BodyParts["RightUpperArm"]
	if not rightArm or not self.HRP then
		return false
	end

	-- 2. Clean Target Position Resolution
	local targetPos: Vector3?

	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			-- R6/R15 adaptability or custom 'UpperBody'
			local upperTorso = target:FindFirstChild("UpperBody")
				or target:FindFirstChild("UpperTorso")
				or target:FindFirstChild("Torso")
			targetPos = upperTorso and upperTorso.Position or target:GetPivot().Position
		elseif target:IsA("BasePart") then
			targetPos = target.Position
		end
	elseif typeof(target) == "Vector3" then
		targetPos = target
	end

	-- Safety check if target type was invalid
	if not targetPos then
		warn("AimRightArmTowards received an invalid target.")
		return false
	end

	-- 3. Activation
	self:ToggleRightArmAimer(true)
	self:ToggleTorsoAimer(true)

	-- 4. Calculate Arm and Torso Aim CFrames
	local origin = rightArm.Position
	local lookCF = CFrame.lookAt(origin, targetPos)

	-- Smooth time-based noise (Procedural Sway)
	local t = os.clock() * HumanConstants.SWAY_SPEED
	local seed = self.NoiseSeed

	local yawNoise = math.noise(seed, t, 0)
	local pitchNoise = math.noise(seed, 0, t)

	local swayYaw = yawNoise * HumanConstants.SWAY_AMOUNT
	local swayPitch = pitchNoise * HumanConstants.SWAY_AMOUNT

	lookCF *= CFrame.Angles(math.rad(90) + swayPitch, swayYaw, 0)
	self.RightArmAimer.CFrame = lookCF

	-- Torso Alignment
	local hrpPos = self.HRP.Position
	local flattenedLookAt = Vector3.new(targetPos.X, hrpPos.Y, targetPos.Z)

	-- Prevent NaN errors if target is directly above/below the HRP
	if (flattenedLookAt - hrpPos).Magnitude > 0.001 then
		self.TorsoAimer.CFrame = CFrame.lookAt(hrpPos, flattenedLookAt)
	end

	-- 5. Non-blocking Alignment Check
	task.defer(function()
		local startTime = os.clock()
		local TIMEOUT = 3 -- Prevents infinite loops if NPC gets stuck

		while os.clock() - startTime < TIMEOUT do
			task.wait()

			-- Ensure instances still exist
			if not self.HRP or not self.HRP.Parent then
				break
			end

			local currentLook = self.HRP.CFrame.LookVector
			local toTarget = (flattenedLookAt - self.HRP.Position)

			if toTarget.Magnitude < 0.1 then
				break
			end -- Already at target
			local targetLook = toTarget.Unit

			local aligned = currentLook:Dot(targetLook) >= 0.99
			local settled = self.HRP.AssemblyAngularVelocity.Magnitude < 0.01

			if aligned and settled then
				break
			end
		end
	end)

	return true
end

function HumanNPC:Ragdoll(duration: number)
	local humanoid = self.Humanoid
	self:UnEquipCurrentTool()

	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

	task.delay(duration, function()
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

			task.wait(0.3)
			if self.Inventory and self.Inventory.EquipWeapon then
				self.Inventory:EquipWeapon("Gun")
			end
		end
	end)
end

function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end

	self.Humanoid:EquipTool(gunTool)

	local gunClass = self.Inventory:GetGun()
	if gunClass then
		gunClass.Holding = true
	end
end

function HumanNPC:UnEquipCurrentTool()
	if self.Humanoid then
		self.Humanoid:UnequipTools()
	end
end

function HumanNPC:Die(shooter: Player?)
	local dead = Human.Die(self)
	if not dead then
		return
	end

	-- shooter should get a money reward for killing, but not if they've somehow killed themselves.
	if shooter and typeof(shooter) == "Instance" and shooter:IsA("Player") then
		AwardHandler.AwardNPCKill(shooter)
	end
end

function HumanNPC:OnDeath()
	Debris:AddItem(self.Character, 30)
	self.AI.StateMachine:Transition("Dead")
	Human.OnDeath(self)
end

return HumanNPC
