local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local HumanConstants = require(script.Parent.HumanConstants)
local HumanSignals = require(script.Parent.HumanSignals)
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local PlayerSignals = require(ServerScriptService.Server.Managers.Player.PlayerSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AnimationIds = require(ReplicatedStorage.Shared.AnimationData.AnimationIds)
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

local Animations = {
	idle = true,
	fall = true,
	run = true,
	walk = true,
	toolnone = true,
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
	self.Animate = character:WaitForChild("Animate")
	self.RootPart = rootPart :: BasePart

	self.Stamina = 100
	self.Sprinting = false
	self.JumpSignalled = false
	self.RollSignalled = false

	self.LimbHealth = table.clone(LimbHealth)
	self.BodyParts = table.clone(BodyParts)
	self.AnimationRefs = table.clone(Animations)

	self.IsRagdolled = false

	self.AnimationControllerState = false

	self.CurrentGun = nil

	self.Legless = false

	self:OnHumanoidStateChange()
	self:AssignBodyParts()
	self:SimulateDefaultLimbs()
	self:SetupPhysicsSettings()
	self:SetupAnimationReferences()

	return self :: any
end
function Human:GetHealthPercentage()
	if self.Health <= 0 then
		return -1
	end
	return self.Health / HumanConstants.MAX_HP
end
function Human:SetupAnimationReferences()
	for _, animName in self.Animate:GetChildren() do
		if self.AnimationRefs[animName.Name] then
			self.AnimationRefs[animName.Name] = animName:GetChildren()
		end
	end

	-- set defaults
	AnimationHandler.SetAnimation(self.AnimationRefs["walk"], `rbxassetid://{AnimationIds.WalkSlow}`)
	AnimationHandler.SetAnimation(self.AnimationRefs["run"], `rbxassetid://{AnimationIds.Run}`)
	AnimationHandler.SetAnimation(self.AnimationRefs["toolnone"], `rbxassetid://{AnimationIds.GunAim}`)
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

function Human:ApplyRollForce(lookDir: Vector3)
	local hrp = self.HRP
	if not hrp then
		return
	end
	-- Get forward direction flattened to XZ plane
	local forward = lookDir
	forward = Vector3.new(forward.X, 0, forward.Z).Unit

	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment

	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	-- Define plane axes (XZ movement only)
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)

	-- Apply planar velocity
	lv.PlaneVelocity = Vector2.new(forward.X * HumanConstants.ROLL_FORCE, forward.Z * HumanConstants.ROLL_FORCE)

	lv.MaxForce = hrp.AssemblyMass * 7000

	lv.Parent = hrp

	-- Cleanup after duration
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

function Human:AssignBodyParts()
	for _, obj in self.Character:GetChildren() do
		if obj:IsA("Accessory") then
			local accessory: BasePart = obj:FindFirstChild("Handle")
			if accessory then
				accessory.CanCollide = false
				accessory.CanQuery = false
				accessory.CanTouch = false
				accessory.CollisionGroup = "Player"
			end
			continue
		end

		if BodyParts[obj.Name] then
			obj.CanQuery = true
			obj.CanCollide = true
			obj.CollisionGroup = "Player"
			self.BodyParts[obj.Name] = obj
		end

		if obj:IsA("BasePart") then
			obj.CollisionGroup = "Player"
		end
	end
	self.HRP:SetNetworkOwner(nil)
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
			else
				self.AnimationControllerState = true
			end

			for _, j in self.Character:GetDescendants() do
				if j:IsA("AnimationConstraint") and j.Name ~= "Root" then
					j.Enabled = self.AnimationControllerState
				end
			end
		end)
	)
end

-- fix right arm to face forward correctly and make gun non collidable so shooting
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

	rightWristBallSocket.LimitsEnabled = false
	rightWristBallSocket.UpperAngle = 180
	rightWristBallSocket.TwistUpperAngle = 0
	rightWristBallSocket.TwistLowerAngle = -50
	rightShoulderBallSocket.TwistLimitsEnabled = false
	rightShoulderBallSocket.UpperAngle = 89

	-- disable gun's collision
	for _, part: MeshPart in pairs(gun:GetChildren()) do
		if not part:IsA("MeshPart") then
			continue
		end
		part.CanCollide = false
	end
end

function Human:SetCrawlState()
	print(self.HumanType)
	local parts = self.BodyParts

	if (not parts.LeftUpperLeg or not parts.LeftLowerLeg) and (not parts.RightUpperLeg or not parts.RightLowerLeg) then
		if self.Legless then
			return
		end
		self.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)

		if self.HumanType == "Player" then
			HumanSignals.RagdollClient:Fire(self.Player)
			self.Humanoid:UnequipTools()
		end

		AnimationHandler.StopAllAnimationTracks(self.Humanoid)

		local idle: Animation = self.AnimationRefs["idle"]
		local run: Animation = self.AnimationRefs["run"]
		local toolequip = self.AnimationRefs["toolnone"]
		local walk: Animation = self.AnimationRefs["walk"]
		local fall: Animation = self.AnimationRefs["fall"]

		if not idle or not run then
			warn("Missing animation references to enable crawl anim")
			return
		end

		print("Both legs gone")

		-- set crawl anims
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		hrp.CanCollide = false
		AnimationHandler.SetAnimation(idle, `rbxassetid://{AnimationIds.LeglessGunIdle}`)
		AnimationHandler.SetAnimation(run, `rbxassetid://{AnimationIds.LeglessMove}`)
		AnimationHandler.SetAnimation(walk, `rbxassetid://{AnimationIds.LeglessMove}`)
		AnimationHandler.SetAnimation(toolequip, `rbxassetid://{AnimationIds.LeglessGunIdle}`)
		AnimationHandler.SetAnimation(fall, `rbxassetid://{AnimationIds.LeglessGunIdle}`)

		self.Humanoid.UseJumpPower = true
		self.Humanoid.JumpPower = 0
		self.Humanoid.WalkSpeed = 8
		self.Humanoid.HipHeight = 3

		self:FixCrawlADS()

		self.Legless = true
	end
end

function Human:DisableLimb(limbName: string)
	local limb = self.Character[limbName]
	if not limb then
		return
	end

	local animationConstraint: AnimationConstraint? = limb:FindFirstChildWhichIsA("AnimationConstraint", true)
	local ballSocket: BallSocketConstraint? = limb:FindFirstChildOfClass("BallSocketConstraint")

	if animationConstraint then
		animationConstraint.Enabled = false
		animationConstraint.IsKinematic = false
		print(`${animationConstraint.Name} animation constraint disabled!`)
	end

	if ballSocket then
		ballSocket.LimitsEnabled = false
		ballSocket.MaxFrictionTorque = 0
		print(`${limbName} ball socket disabled!`)
	end

	if limbName ~= "Head" then
		ServerSoundHandler:PlaySoundTo(nil, "BoneSnap", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })
	end
end

function Human:DestroyLimb(limbName: string)
	self.BodyParts[limbName]:Destroy()
	self.BodyParts[limbName] = nil
	ServerSoundHandler:PlaySoundTo(nil, "LimbDismember", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })
	self:SetCrawlState()
end

--[=[
	Returns whether the character is alive (Humanoid health > 0 and character exists).
	
	@return boolean
]=]
function Human.IsAlive(self: any): boolean
	if not self.Character or not self.Character.Parent then
		return false
	end

	if not self.Humanoid or self.Humanoid.Health <= 0 then
		return false
	end

	return true
end

--[=[
	Applies death ragdoll state
]=]
function Human:OnDeath()
	task.spawn(function()
		for _, obj in self.Character:GetDescendants() do
			if obj:IsA("AnimationConstraint") then
				obj.Enabled = false
			elseif obj:IsA("BallSocketConstraint") then
				obj.MaxFrictionTorque = 10
			elseif obj:IsA("BasePart") then
				obj.CollisionGroup = "Dead"
			end
		end
	end)

	self:Destroy()
end

--[=[
	Applies an impulse force to the ragdolled character (e.g., for knockback effects).
	
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
