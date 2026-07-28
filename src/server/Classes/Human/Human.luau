local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanSignals = require(script.Parent.HumanSignals)
local Inventory = require(script.Parent.Inventory)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerSignals = require(ServerScriptService.Server.Managers.Player.PlayerSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local BloodFlowEmitter = ReplicatedStorage.Shared.Templates.BloodFlow
type Gun = ClassTypes.Gun
type Human = ClassTypes.Human

local RagdollDisabledStates = {
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local SimulatingLimbs = {
	["LeftShoulder"] = true,
	["RightShoulder"] = true,
	["LeftElbow"] = true,
	["RightElbow"] = true,
	["RightUpperArm"] = true,
	["LeftWrist"] = true,
	["RightWrist"] = true,
}

-- Applied on UpperTorso and LowerTorso
local DismemberAttachments = {
	LeftUpperArm = "LeftShoulderRigAttachment",
	LeftUpperLeg = "LeftHipRigAttachment",
	RightUpperLeg = "RightHipRigAttachment",
	Head = "NeckRigAttachment",
}

local DismemberLimbBloodRequirement = {
	LeftUpperArm = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	Head = true,
}
local LIMB_CHAIN = {
	LeftUpperLeg = { "LeftLowerLeg", "LeftFoot" },
	LeftLowerLeg = { "LeftFoot" },
	RightUpperLeg = { "RightLowerLeg", "RightFoot" },
	RightLowerLeg = { "RightFoot" },
	LeftUpperArm = { "LeftLowerArm", "LeftHand" },
	LeftLowerArm = { "LeftHand" },
	RightUpperArm = { "RightLowerArm", "RightHand" },
	RightLowerArm = { "RightHand" },
}

local LimbHealth = {
	Head = 50,
	UpperTorso = 85,
	LowerTorso = 70,
	LeftUpperArm = 60,
	LeftLowerArm = 60,
	RightUpperArm = 999,
	RightLowerArm = 999,
	LeftUpperLeg = 40,
	LeftLowerLeg = 40,
	RightUpperLeg = 40,
	RightLowerLeg = 40,
}

local BallSocketMaxFrictionTorques = {
	LeftHand = 16.976,

	LeftFoot = 26.867,

	LeftLowerLeg = 71.363,
	LeftUpperLeg = 25.812,

	LeftLowerArm = 58.609,
	LeftUpperArm = 50.275,

	RightHand = 16.976,

	RightFoot = 26.867,

	RightLowerLeg = 71.363,
	RightUpperLeg = 25.812,

	RightLowerArm = 58.609,
	RightUpperArm = 50.275,
}

local BodyParts = {
	Head = true,

	UpperTorso = true,
	LowerTorso = true,

	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,

	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,

	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,

	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local DisabledBodyParts = {
	LeftUpperArm = false,
	LeftLowerArm = false,

	RightUpperArm = false,
	RightLowerArm = false,

	LeftUpperLeg = false,
	LeftLowerLeg = false,

	RightUpperLeg = false,
	RightLowerLeg = false,

	RightHand = false,
	LeftHand = false,
}

local BloodEmitterRefs = {
	LeftUpperArm = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	Head = true,
}

-- Module
local Human = {}
Human.__index = Human

function Human.new(humanoid: Humanoid?): Human
	assert(humanoid, "Human.new: humanoid cannot be nil")
	local character = humanoid:FindFirstAncestorOfClass("Model")
	assert(character, "Human.new: character cannot be nil")

	local rootPart = humanoid.RootPart or character:FindFirstChild("HumanoidRootPart")
	assert(rootPart, "Human.new: character must contain a HumanoidRootPart")

	local self = setmetatable({}, Human)
	self.Janitor = Janitor.new()
	self.HumanType = "Base"
	self.Health = HumanConstants.MAX_HP
	self.Character = character
	self.Humanoid = humanoid
	self.HRP = rootPart
	self.Dead = false
	self.Name = humanoid.Parent and humanoid.Parent.Name
	self.Animator = humanoid:FindFirstChildOfClass("Animator")
	self.Stamina = 100
	self.Inventory = Inventory.new(self)
	self.Moving = false
	self.Sprinting = false
	self.LastInvincible = nil
	self.ActiveInvincibleDelayHandle = nil
	self.CombatLogTimerHandle = nil
	self.JumpSignalled = false
	self.RollSignalled = false
	self.KickSignalled = false
	self.Invincible = false
	self.InCombat = false
	self.CombatTimer = 0

	self.LimbHealth = table.clone(LimbHealth)
	self.BodyParts = table.clone(BodyParts)
	self.DisabledBodyParts = table.clone(DisabledBodyParts)
	self.BloodEmitterRefs = table.clone(BloodEmitterRefs)

	self.IsRagdolled = false

	self.AnimationControllerState = false

	self:OnHumanoidStateChange()
	self:SimulateDefaultLimbs()
	self:SetupPhysicsSettings()
	self:SetupAttributes()
	self:SetupMovementDetector()

	return self :: any
end
function Human:SetupMovementDetector()
	local humanoid = self.Humanoid
	self.Janitor:Add(humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 then
			self.Moving = true
		else
			self.Moving = false
		end
	end))

	humanoid.MaxSlopeAngle = 50
end
function Human:SetupAttributes()
	if not self.Character then
		warn("Cannot setup human attributes, character model missing")
		return
	end
	self.Character:SetAttribute("Legless", false)
end

function Human:IsLegless()
	if not self.Character then
		warn("Cannot get legless state, character model missing")
		return
	end

	return self.Character:GetAttribute("Legless")
end

function Human:UpdateLeglessState(isLegless: boolean)
	if not self.Character then
		warn("Cannot update legless state, missing character")
		return
	end

	self.Character:SetAttribute("Legless", isLegless)
end

function Human:GetHealthPercentage()
	if self.Health <= 0 then
		return -1
	end
	return self.Health / HumanConstants.MAX_HP
end

function Human:SetInCombat(InCombat: boolean)
	if not self then
		return
	end
	self.InCombat = InCombat

	if InCombat then
		self.CombatTimer = 10
		self:StartCombatLogTimer()
	else
		if self.CombatLogTimerHandle then
			pcall(task.cancel, self.CombatLogTimerHandle)
			self.CombatLogTimerHandle = nil
		end
	end
end

function Human:StartCombatLogTimer()
	if self.CombatLogTimerHandle then
		pcall(task.cancel, self.CombatLogTimerHandle)
		self.CombatLogTimerHandle = nil
	end

	-- if delay finishes, not been hit for a while, so not combat logged anymore
	self.CombatLogTimerHandle = task.delay(self.CombatTimer, function()
		self:SetInCombat(false)
	end)
end

function Human:ToggleInvincibleHighlight(state: boolean)
	local highlight = self.Character and self.Character:FindFirstChildOfClass("Highlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "InvincibilityHighlight"
		highlight.OutlineTransparency = 1
		highlight.FillColor = Color3.fromRGB(1, 170, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = self.Character
	end

	if state then
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end

function Human:SetInvincible(isInvincible: boolean, excludeFromCooldown: boolean?)
	if self.Invincible == isInvincible then
		return
	end

	if
		isInvincible
		and self.LastInvincible
		and (os.time() - self.LastInvincible) < HumanConstants.GUI_INTERACTION_INVINCIBILITY_COOLDOWN
	then
		warn("Cooldown, not setting invincible")
		return
	end

	self.Invincible = isInvincible

	if self.Invincible then
		self:ToggleInvincibleHighlight(true)
		if not excludeFromCooldown then
			self.LastInvincible = os.time()
		end
	else
		self:ToggleInvincibleHighlight(false)
	end
end

function Human:SetInvincibleFor(duration: number, excludeFromCooldown: boolean?)
	self:SetInvincible(true, excludeFromCooldown)
	self.ActiveInvincibleDelayHandle = task.delay(duration, function()
		if type(self.SetInvincible) ~= "function" then
			return
		end
		if self and not CollectionService:HasTag(self.Character, "Dead") then
			self:SetInvincible(false)
		end
	end)
end

function Human:SetupPhysicsSettings()
	local rightArm = Utility.GetInstance(self.Character, true, "RightUpperArm")
	local rightLowerArm = Utility.GetInstance(self.Character, true, "RightLowerArm")
	local rightHand = Utility.GetInstance(self.Character, true, "RightHand")

	local rightShoulder: AnimationConstraint =
		Utility.GetInstance(rightArm, true, "RightShoulder") :: AnimationConstraint

	local rightElbow: AnimationConstraint =
		Utility.GetInstance(rightLowerArm, true, "RightElbow") :: AnimationConstraint

	local rightWrist: AnimationConstraint = Utility.GetInstance(rightHand, true, "RightWrist") :: AnimationConstraint

	-- important to be high so the arm doesn't get stuck when going back to original position (when ADS)
	rightShoulder.MaxTorque = 9999
	rightElbow.MaxTorque = 9999
	rightWrist.MaxTorque = 9999

	local rightArmSocket: BallSocketConstraint =
		Utility.GetInstance(rightArm, true, "RightShoulderBallSocket") :: BallSocketConstraint

	local rightLowerArmSocket: BallSocketConstraint =
		Utility.GetInstance(rightLowerArm, true, "RightElbowBallSocket") :: BallSocketConstraint

	rightArmSocket.UpperAngle = 90

	rightLowerArmSocket.UpperAngle = 0
	rightLowerArmSocket.TwistUpperAngle = 5
	rightLowerArmSocket.TwistLowerAngle = 0
end

function Human:ApplyKickForce()
	local rightFoot = self.BodyParts["RightFoot"]
	if self.DisabledBodyParts["RightFoot"] == true then
		return
	end
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams:AddToFilter(self.Character)

	local kickedObjects = workspace:GetPartBoundsInRadius(
		rightFoot.Position + self.HRP.CFrame.LookVector * HumanConstants.KICK_RADIUS,
		HumanConstants.KICK_RADIUS,
		overlapParams
	)

	for _, obj in kickedObjects do
		if CollectionService:HasTag(obj, "Destroyable") then
			local mass = obj.AssemblyMass
			obj:ApplyImpulse(
				(self.HRP.CFrame.LookVector + HumanConstants.KICK_HEIGHT).Unit * HumanConstants.KICK_FORCE * mass
			)
			obj:ApplyAngularImpulse(self.HRP.CFrame.LookVector * HumanConstants.KICK_ANGULAR_FORCE * mass)
		end
	end
end
function Human:ApplyRollForce()
	local hrp = self.HRP
	if not hrp then
		return
	end

	local humanoid = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local moveDir = humanoid.MoveDirection
	local forward = (moveDir.Magnitude >= 0.1 and moveDir or hrp.CFrame.LookVector) * Vector3.new(1, 0, 1)

	if forward.Magnitude < 0.01 then
		forward = hrp.CFrame.LookVector
	end
	forward = forward.Unit

	-- Zero out existing horizontal velocity first so forces don't stack
	local currentVel = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)

	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	-- Use LinearVelocity in Line mode to set an exact target speed,
	-- with a capped MaxForce to prevent spikes
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.LineDirection = forward
	lv.LineVelocity = HumanConstants.ROLL_FORCE -- treat this as a speed (studs/s)
	lv.MaxForce = math.huge
	lv.Parent = hrp

	-- Ease out: reduce force partway through so it doesn't suddenly stop
	local halfDuration = HumanConstants.ROLL_DURATION * 0.55
	task.delay(halfDuration, function()
		if lv and lv.Parent then
			lv.LineVelocity = lv.LineVelocity * 0.4
		end
	end)

	task.delay(HumanConstants.ROLL_DURATION, function()
		if lv and lv.Parent then
			lv:Destroy()
		end
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
		self.RollSignalled = false
	end)
end

function Human:HealAll()
	-- reset limb constraints and hp
	for key, bodyPart in self.BodyParts do
		if not bodyPart then
			continue
		end

		if key == "Head" or key == "UpperTorso" or key == "LowerTorso" then
			self.LimbHealth[key] = LimbHealth[key]
			continue
		end

		self.DisabledBodyParts[key] = false
		bodyPart.Transparency = 0
		bodyPart:SetAttribute("Destroyed", false)
		bodyPart.CanQuery = true
		bodyPart.CanTouch = true

		local animationConstraint: AnimationConstraint? = bodyPart:FindFirstChildWhichIsA("AnimationConstraint", true)
		local ballSocket: BallSocketConstraint? = bodyPart:FindFirstChildOfClass("BallSocketConstraint")

		if animationConstraint then
			animationConstraint.Enabled = true
		end

		if ballSocket then
			ballSocket.LimitsEnabled = true
			ballSocket.MaxFrictionTorque = BallSocketMaxFrictionTorques[key]
		end

		self.LimbHealth[key] = LimbHealth[key]
		self.Health = HumanConstants.MAX_HP

		if self.BloodEmitterRefs[key] then
			self.BloodEmitterRefs[key].Enabled = false
		end
	end

	if self:IsLegless() then
		self:RevertCrawlState()
	end
end

function Human:AssignBodyParts(tagName: string)
	for _, obj in self.Character:GetChildren() do
		-- handle accessories collision
		if obj:IsA("Accessory") then
			local accessory: BasePart = obj:FindFirstChild("Handle")
			if accessory then
				accessory.CanCollide = false
				accessory.CanQuery = false
				accessory.CanTouch = false
				accessory.CollisionGroup = "Accessory"
			end
			continue
		end

		-- add body parts to table
		if BodyParts[obj.Name] then
			obj.CanQuery = true
			obj.CanCollide = true
			obj.CollisionGroup = tagName
			self.BodyParts[obj.Name] = obj
		end

		if obj:IsA("BasePart") then
			obj.CollisionGroup = tagName
		end
	end
end

function Human:SimulateDefaultLimbs()
	-- setting this to HumanoidRootPart prevents any sliding from occuring, very IMPORTANT
	local physicalProperties: PhysicalProperties = PhysicalProperties.new(100, 2, 0.5, 1, 1)
	self.HRP.CustomPhysicalProperties = physicalProperties

	for _, obj in self.Character:GetDescendants() do
		if not obj:IsA("AnimationConstraint") then
			continue
		end

		if SimulatingLimbs[obj.Name] then
			obj.IsKinematic = false
			obj.MaxTorque = 700
		end
	end
end

-- ragdoll when player's state is equal to any CharacterStates
function Human:OnHumanoidStateChange()
	if not self.Humanoid then
		error("Missing humanoid reference in human class!")
	end
	-- keep BallSocketConstraints on death
	self.Humanoid.BreakJointsOnDeath = false

	self.Janitor:Add(
		self.Humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
			if RagdollDisabledStates[newState] then
				self.AnimationControllerState = false
				self.IsRagdolled = true
			else
				self.AnimationControllerState = true
				self.IsRagdolled = false
			end

			for _, j in self.Character:GetDescendants() do
				if j:IsA("AnimationConstraint") and j.Name ~= "Root" then
					j.Enabled = self.AnimationControllerState
				end
			end
			if newState == Enum.HumanoidStateType.Dead then
				self:OnDeath()
			end
		end)
	)
end

function Human:OnHit(damage: number, damageMultiplier: number, limbName: string, shooter: Player | Model)
	self.LimbHealth[limbName] -= damage
	self.Health -= damage * damageMultiplier
	self:SetInCombat(true)

	local shooterIsPlayer = typeof(shooter) == "Instance" and shooter:IsA("Player")

	if shooterIsPlayer then
		local shooterPlayer = shooter :: Player
		if limbName == "Head" then
			ServerSoundHandler:PlaySoundTo(
				shooterPlayer,
				"Headshot",
				{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
			)
		end
		HumanSignals.SetShooterInCombat:Fire(shooter)
	end
end

-- Set humanoid health to 0 to initiate death
function Human:Die(shooter: Player?)
	if self.Dead then
		return false
	end
	if self.Humanoid then
		self.Humanoid.Health = 0
	else
		warn(`[Human:Die] Missing humanoid, so can't kill`)
		return false
	end
	self.Dead = true
	return true
end

-- Fix right arm to face forward correctly and make gun non collidable so shooting
-- works whilst legless
function Human:FixCrawlADS()
	local rightHand: MeshPart = self.BodyParts["RightHand"]

	local rightWristBallSocket: BallSocketConstraint = Utility.GetInstance(rightHand, false, "RightWristBallSocket")

	local rightUpperArm: MeshPart = self.BodyParts["RightUpperArm"]
	local rightShoulderBallSocket: BallSocketConstraint =
		Utility.GetInstance(rightUpperArm, false, "RightShoulderBallSocket")
	local rightLowerArm: MeshPart = self.BodyParts["RightLowerArm"]

	assert(rightUpperArm, "[Human:FixCrawlADS] RightUpperArm missing from BodyParts")
	assert(rightLowerArm, "[Human:FixCrawlADS] RightLowerArm missing from BodyParts")

	rightWristBallSocket.LimitsEnabled = true
	rightWristBallSocket.UpperAngle = 0
	rightWristBallSocket.TwistLimitsEnabled = true
	rightWristBallSocket.TwistUpperAngle = 0
	rightWristBallSocket.TwistLowerAngle = 0

	rightShoulderBallSocket.TwistLimitsEnabled = false
	rightShoulderBallSocket.UpperAngle = 100

	-- disable gun's collision
	local gun = self.Inventory:GetGun()

	if gun then
		gun:ToggleCollision(false)
	end
end

function Human:SetCrawlState()
	warn("Ran SetCrawlState base class, you shouldn't be able to see this")
end

function Human:MakeLimbFloppy(limbPart)
	task.spawn(function()
		local animationConstraint: AnimationConstraint? = limbPart:FindFirstChildWhichIsA("AnimationConstraint", true)
		local ballSocket: BallSocketConstraint? = limbPart:FindFirstChildOfClass("BallSocketConstraint")
		local limbName = limbPart.Name
		limbPart.CanCollide = false
		limbPart.Massless = true
		if animationConstraint then
			animationConstraint.Enabled = false
			animationConstraint.MaxForce = 0
			animationConstraint.MaxTorque = 0
			print(`{animationConstraint.Name} animation constraint disabled!`)

			-- If we ragdoll and stand up, it resets everything so reapply this
			self.Janitor:Add(animationConstraint:GetPropertyChangedSignal("Enabled"):Connect(function()
				if self.DisabledBodyParts[limbName] == true then
					animationConstraint.Enabled = false
				end
			end))
		end

		if ballSocket then
			ballSocket.LimitsEnabled = false
			ballSocket.MaxFrictionTorque = 0
			print(`{limbName} ball socket disabled!`)
		end

		if self.DisabledBodyParts[limbName] == false then
			self.DisabledBodyParts[limbName] = true
		end
	end)
end

function Human:DisableLimb(limbName: string)
	local limb = self.Character[limbName]
	if not limb then
		return
	end
	self:MakeLimbFloppy(limb)

	local chainDisable = LIMB_CHAIN[limbName]
	if chainDisable then
		for _, chainLimb in chainDisable do
			self:MakeLimbFloppy(self.Character[chainLimb])
		end
	end

	if limbName ~= "Head" then
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"BoneSnap",
			limb.CFrame.Position,
			{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
		)
	end

	self:SetCrawlState()
end

function Human:SetupBloodEmitters()
	local upperTorso = self.BodyParts["UpperTorso"]
	local lowerTorso = self.BodyParts["LowerTorso"]

	if not upperTorso or not lowerTorso then
		error("[SetupBloodEmitters] Failed to get torso references")
	end

	-- legs
	for limbName, attachmentName in DismemberAttachments do
		local attachment = if lowerTorso:FindFirstChild(attachmentName)
			then lowerTorso:FindFirstChild(attachmentName)
			else upperTorso:FindFirstChild(attachmentName)
		if not attachment then
			warn("Attachment not found")
			continue
		end

		local bloodEmitter: ParticleEmitter = BloodFlowEmitter:Clone()
		local isLeg = string.find(limbName:lower(), "leg")
		local isHead = string.find(limbName:lower(), "head")
		local isArm = string.find(limbName:lower(), "arm")

		if isLeg then
			bloodEmitter.EmissionDirection = Enum.NormalId.Bottom
		-- arm
		elseif isArm then
			bloodEmitter.EmissionDirection = if string.find(limbName:lower(), "left")
				then Enum.NormalId.Left
				else Enum.NormalId.Right
		elseif isHead then
			bloodEmitter.EmissionDirection = Enum.NormalId.Top
		end

		self.BloodEmitterRefs[limbName] = bloodEmitter
		bloodEmitter.Enabled = false
		bloodEmitter.Parent = attachment
	end
end

function Human:ToggleBloodEmitter(limbName: string, state: boolean)
	local bloodRef = self.BloodEmitterRefs[limbName]
	if not bloodRef then
		return
	end
	bloodRef.Enabled = state
end

function Human:HideLimb(limb)
	local limbName = limb.Name
	limb.Transparency = 1
	limb:SetAttribute("Destroyed", true)
	limb.CanQuery = false
	limb.CanTouch = false

	if self.DisabledBodyParts[limbName] == false then
		self.DisabledBodyParts[limbName] = true
	end

	if self.LimbHealth[limbName] then
		self.LimbHealth[limbName] = HumanConstants.LIMB_DISMEMBER_HP
	end
end

function Human:DestroyLimb(limbName: string)
	if not self.BodyParts or not self.BodyParts[limbName] then
		return
	end
	local dependents = LIMB_CHAIN[limbName]
	local limb = self.BodyParts[limbName]

	self:HideLimb(limb)
	ServerSoundHandler:PlaySoundTo(nil, "LimbDismember", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })

	-- hide connected parts as well
	if dependents then
		for _, dependentName in dependents do
			local childLimb = self.BodyParts[dependentName]
			self:HideLimb(childLimb)
		end
	end

	if DismemberLimbBloodRequirement[limbName] then
		self:ToggleBloodEmitter(limbName, true)
	end

	if limbName == "Head" then
		self.Health = 0
	end

	self:SetCrawlState()
end

--[=[d
	Applies death ragdoll state
]=]
function Human:OnDeath()
	task.spawn(function()
		CollectionService:AddTag(self.Character, "Dead")
		for _, obj in self.Character:GetDescendants() do
			if obj:IsA("AnimationConstraint") then
				obj.Enabled = false
			elseif obj:IsA("BallSocketConstraint") then
				obj.MaxFrictionTorque = 10
			elseif obj:IsA("BasePart") then
				obj.CollisionGroup = "Dead"
				CollectionService:RemoveTag(obj, "NPC")
			end
		end
	end)
	self:Destroy()
end

function Human:Ragdoll(duration: number, force: Vector3?)
	warn("Human:Ragdoll BASE CLASS, YOU SHOULD NOT SEE THIS")
end

--[=[
	Applies an impulse force to the ragdolled character (e.g., for knockback effects).
	Note if applying to player, it will be sent to client for responsiveness.
	
	@param force Vector3 -- The force vector to apply
	@param position Vector3? -- Optional world position to apply force at (defaults to RootPart position)
]=]
function Human:ApplyImpulse(force: Vector3, position: Vector3?)
	if not self.HRP then
		return
	end

	if position then
		self.HRP:ApplyImpulseAtPosition(force, position)
	else
		self.HRP:ApplyImpulse(force)
	end
end

function Human:Destroy()
	if self.Inventory then
		self.Inventory:Destroy()
	end

	PlayerSignals.RemovePlayerClass:Fire(self.Humanoid)

	if self.CombatLogTimerHandle then
		pcall(task.cancel, self.CombatLogTimerHandle)
		self.CombatLogTimerHandle = nil
	end

	self.Janitor:Destroy()

	table.clear(self)
	setmetatable(self, nil)

	print(`Human class destroyed!`)
end

return Human
