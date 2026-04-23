local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(script.Parent.HumanConstants)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerSignals = require(ServerScriptService.Server.Managers.Player.PlayerSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

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

local LimbHealth = {
	Head = 35,
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
	self.HRP = humanoid.RootPart
	self.RootPart = rootPart :: BasePart
	self.Dead = false
	self.Animator = humanoid:FindFirstChildOfClass("Animator")
	self.Stamina = 100
	self.Sprinting = false
	self.JumpSignalled = false
	self.RollSignalled = false
	self.KickSignalled = false
	self.Invincible = false

	self.LimbHealth = table.clone(LimbHealth)
	self.BodyParts = table.clone(BodyParts)
	self.DisabledBodyParts = table.clone(DisabledBodyParts)

	self.IsRagdolled = false

	self.AnimationControllerState = false

	self.CurrentGun = nil
	self.CurrentThrowable = nil

	self.Legless = false

	self:OnHumanoidStateChange()
	self:SimulateDefaultLimbs()
	self:SetupPhysicsSettings()

	return self :: any
end

function Human:GetHealthPercentage()
	if self.Health <= 0 then
		return -1
	end
	return self.Health / HumanConstants.MAX_HP
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

	rightLowerArmSocket.UpperAngle = 5
	rightLowerArmSocket.TwistUpperAngle = 0
	rightLowerArmSocket.TwistLowerAngle = 0
end

function Human:ApplyKickForce()
	local rightFoot = self.BodyParts["RightFoot"]
	if not rightFoot then
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

	-- Get current movement direction from Humanoid
	local moveDir = humanoid.MoveDirection

	-- If not moving, fall back to facing direction
	if moveDir.Magnitude < 0.1 then
		moveDir = hrp.CFrame.LookVector
	end

	-- Flatten to XZ plane
	local forward = Vector3.new(moveDir.X, 0, moveDir.Z)
	if forward.Magnitude < 0.01 then
		forward = hrp.CFrame.LookVector
	end
	forward = forward.Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)

	lv.PlaneVelocity = Vector2.new(forward.X * HumanConstants.ROLL_FORCE, forward.Z * HumanConstants.ROLL_FORCE)

	lv.MaxForce = hrp.AssemblyMass * 7000
	lv.Parent = hrp

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

function Human:AssignBodyParts(tagName: string)
	for _, obj in self.Character:GetChildren() do
		-- handle accessories collision
		if obj:IsA("Accessory") then
			local accessory: BasePart = obj:FindFirstChild("Handle")
			if accessory then
				accessory.CanCollide = false
				accessory.CanQuery = false
				accessory.CanTouch = false
				accessory.CollisionGroup = tagName
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

-- apply damage to self
function Human:OnHit(damage: number, damageMultiplier: number, limbName: string, shooter: Player | Model)
	self.LimbHealth[limbName] -= damage
	self.Health -= damage * damageMultiplier

	-- damage dealer's client plays headshot sound
	if shooter and shooter:IsA("Player") then
		if limbName == "Head" then
			ServerSoundHandler:PlaySoundTo(
				shooter,
				"Headshot",
				{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
			)
		end
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

	local gun = self.CurrentGun.Tool

	assert(gun, "[Human:FixCrawlADS] gun tool missing")
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
	for _, part: MeshPart in gun:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end
		part.CanCollide = false
	end
end

function Human:SetCrawlState()
	warn("Ran SetCrawlState base class, you shouldn't be able to see this")
end

function Human:DisableLimb(limbName: string)
	local limb = self.Character[limbName]
	if not limb then
		return
	end

	local animationConstraint: AnimationConstraint? = limb:FindFirstChildWhichIsA("AnimationConstraint", true)
	local ballSocket: BallSocketConstraint? = limb:FindFirstChildOfClass("BallSocketConstraint")

	limb.CanCollide = false
	if animationConstraint then
		animationConstraint.Enabled = false
		print(`{animationConstraint.Name} animation constraint disabled!`)
	end

	if ballSocket then
		ballSocket.LimitsEnabled = false
		ballSocket.MaxFrictionTorque = 0
		print(`{limbName} ball socket disabled!`)
	end

	if self.DisabledBodyParts[limbName] == false then
		self.DisabledBodyParts[limbName] = true
	end

	if limbName ~= "Head" then
		ServerSoundHandler:PlaySoundTo(nil, "BoneSnap", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })
	end

	self:SetCrawlState()
end

function Human:DestroyLimb(limbName: string)
	if not self.BodyParts or not self.BodyParts[limbName] then
		return
	end
	self.BodyParts[limbName]:Destroy()
	self.BodyParts[limbName] = nil
	ServerSoundHandler:PlaySoundTo(nil, "LimbDismember", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })

	if self.DisabledBodyParts[limbName] == false then
		self.DisabledBodyParts[limbName] = true
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

function Human:Ragdoll(duration: number)
	warn("Human:Ragdoll BASE CLASS, YOU SHOULD NOT SEE THIS")
end

--[=[
	Applies an impulse force to the ragdolled character (e.g., for knockback effects).
	Note if applying to player, it will be sent to client for responsiveness.
	
	@param force Vector3 -- The force vector to apply
	@param position Vector3? -- Optional world position to apply force at (defaults to RootPart position)
]=]
function Human:ApplyImpulse(force: Vector3, position: Vector3?)
	if not self.RootPart or not self.RootPart.Parent then
		return
	end

	if position then
		self.RootPart:ApplyImpulseAtPosition(force, position)
	else
		self.RootPart:ApplyImpulse(force)
	end
end

function Human:Destroy()
	PlayerSignals.RemovePlayerClass:Fire(self.Humanoid)
	if self.CurrentGun then
		self.CurrentGun:Destroy()
		self.CurrentGun = nil
	end

	self.Janitor:Destroy()

	table.clear(self)
	setmetatable(self, nil)

	print(`Human class destroyed!`)
end

return Human
