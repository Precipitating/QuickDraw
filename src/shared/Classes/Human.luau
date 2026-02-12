--!strict
--[[
	Human Class
	A class representing a human character with an embedded ragdoll system.
	
	Usage:
		local Human = require(path.to.Human)
		
		-- Create from an existing character model
		local human = Human.new(characterModel)
		
		-- Enable ragdoll
		human:Ragdoll()
		
		-- Disable ragdoll
		human:Unragdoll()
		
		-- Toggle ragdoll
		human:ToggleRagdoll()
		
		-- Cleanup
		human:Destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)

-- Types
export type JointData = {
	Motor6D: Motor6D,
	Part0: BasePart,
	Part1: BasePart,
	C0: CFrame,
	C1: CFrame,
	BallSocket: BallSocketConstraint?,
	Attachment0: Attachment?,
	Attachment1: Attachment?,
}

export type RagdollConfig = {
	BreakJointsOnRagdoll: boolean,
	RagdollDuration: number?,
	CollisionGroupName: string?,
}

export type Human = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	IsRagdolled: boolean,
	Config: RagdollConfig,

	Ragdoll: (self: Human) -> (),
	Unragdoll: (self: Human) -> (),
	ToggleRagdoll: (self: Human) -> (),
	IsAlive: (self: Human) -> boolean,
	GetJointData: (self: Human) -> { JointData },
	SetConfig: (self: Human, config: RagdollConfig) -> (),
	Destroy: (self: Human) -> (),
}

-- Constants
local DEFAULT_CONFIG: RagdollConfig = {
	BreakJointsOnRagdoll = false,
	RagdollDuration = nil,
	CollisionGroupName = nil,
}

--[[
	Joint constraint configuration for realistic human ragdoll physics.
	
	Each joint defines:
	- UpperAngle: The cone angle limit (how far the joint can swing from its axis)
	- TwistLowerAngle / TwistUpperAngle: How far the joint can twist along its axis
	- MaxFrictionTorque: Resistance to movement (simulates muscle/tendon resistance)
	
	These values are tuned to approximate real human joint ranges of motion.
]]
local JOINT_LIMITS: { [string]: { UpperAngle: number, TwistLowerAngle: number, TwistUpperAngle: number, MaxFrictionTorque: number } } =
	{
		["Neck"] = {
			UpperAngle = 35,
			TwistLowerAngle = -40,
			TwistUpperAngle = 40,
			MaxFrictionTorque = 50,
		},

		["Left Shoulder"] = {
			UpperAngle = 110,
			TwistLowerAngle = -90,
			TwistUpperAngle = 90,
			MaxFrictionTorque = 50,
		},

		["Right Shoulder"] = {
			UpperAngle = 110,
			TwistLowerAngle = -90,
			TwistUpperAngle = 90,
			MaxFrictionTorque = 50,
		},

		["Left Elbow"] = {
			UpperAngle = 145,
			TwistLowerAngle = 0,
			TwistUpperAngle = 0,
			MaxFrictionTorque = 50,
		},

		["Right Elbow"] = {
			UpperAngle = 145,
			TwistLowerAngle = 0,
			TwistUpperAngle = 0,
			MaxFrictionTorque = 50,
		},

		["Left Wrist"] = {
			UpperAngle = 40,
			TwistLowerAngle = -60,
			TwistUpperAngle = 60,
			MaxFrictionTorque = 50,
		},

		["Right Wrist"] = {
			UpperAngle = 40,
			TwistLowerAngle = -60,
			TwistUpperAngle = 60,
			MaxFrictionTorque = 50,
		},

		["Left Hip"] = {
			UpperAngle = 90,
			TwistLowerAngle = -45,
			TwistUpperAngle = 45,
			MaxFrictionTorque = 50,
		},

		["Right Hip"] = {
			UpperAngle = 90,
			TwistLowerAngle = -45,
			TwistUpperAngle = 45,
			MaxFrictionTorque = 50,
		},

		["Left Knee"] = {
			UpperAngle = 140,
			TwistLowerAngle = 0,
			TwistUpperAngle = 0,
			MaxFrictionTorque = 50,
		},

		["Right Knee"] = {
			UpperAngle = 140,
			TwistLowerAngle = 0,
			TwistUpperAngle = 0,
			MaxFrictionTorque = 50,
		},

		["Left Ankle"] = {
			UpperAngle = 35,
			TwistLowerAngle = -25,
			TwistUpperAngle = 25,
			MaxFrictionTorque = 50,
		},

		["Right Ankle"] = {
			UpperAngle = 35,
			TwistLowerAngle = -25,
			TwistUpperAngle = 25,
			MaxFrictionTorque = 50,
		},

		["Waist"] = {
			UpperAngle = 40,
			TwistLowerAngle = -45,
			TwistUpperAngle = 45,
			MaxFrictionTorque = 50,
		},
	}

-- Module
local Human = {}
Human.__index = Human

--[=[
	Creates a new Human instance from a character model.
	
	@param character Model -- The character model (must contain a Humanoid and HumanoidRootPart)
	@param config RagdollConfig? -- Optional configuration for ragdoll behavior
	@return Human
]=]
function Human.new(player: Player, config: RagdollConfig?): Human
	assert(player, "Human.new: player cannot be nil")

	local character = player.Character
	assert(character, "Human.new: character cannot be nil")

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "Human.new: character must contain a Humanoid")

	local rootPart = humanoid.RootPart or character:FindFirstChild("HumanoidRootPart")
	assert(rootPart, "Human.new: character must contain a HumanoidRootPart")

	local self = setmetatable({}, Human)

	self.Player = player
	self.Character = character
	self.Humanoid = humanoid
	self.RootPart = rootPart :: BasePart
	self.IsRagdolled = false
	self.Config = config or table.clone(DEFAULT_CONFIG)

	-- Internal state
	self._jointData = {} :: { JointData }
	self._ragdollConstraints = {} :: { Instance }
	self._noCollisionConstraints = {} :: { NoCollisionConstraint }
	self._connections = Janitor.new()
	self._destroyed = false
	self._originalStates = {} :: { [string]: any }

	-- Cache all Motor6D joints on creation
	self:_CacheJoints()

	-- Disable the humanoid's built-in state transitions that fight with ragdoll
	self:_ConfigureHumanoidStates()

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end

	return self :: any
end

--[=[
	Creates a Human instance from a Player. Waits for the character if it hasn't loaded yet.
	
	@param player Player -- The player to create a Human from
	@param config RagdollConfig? -- Optional configuration
	@return Human
]=]
function Human.fromPlayer(player: Player, config: RagdollConfig?): Human
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")

	return Human.new(player, config)
end

--[=[
	Configures humanoid state types to prevent the humanoid from fighting
	the ragdoll physics system.
	@private
]=]
function Human._ConfigureHumanoidStates(self: any)
	-- Disable GettingUp so the humanoid doesn't try to auto-recover during ragdoll
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end

--[=[
	Caches all Motor6D joints in the character for ragdoll toggling.
	@private
]=]
function Human._CacheJoints(self: any)
	table.clear(self._jointData)

	for _, descendant in self.Character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant :: Motor6D
			if motor.Part0 and motor.Part1 then
				local jointData: JointData = {
					Motor6D = motor,
					Part0 = motor.Part0,
					Part1 = motor.Part1,
					C0 = motor.C0,
					C1 = motor.C1,
					BallSocket = nil,
					Attachment0 = nil,
					Attachment1 = nil,
				}
				table.insert(self._jointData, jointData)
			end
		end
	end
end

--[=[
	Returns the cached joint data.
	
	@return { JointData }
]=]
function Human.GetJointData(self: any): { JointData }
	return self._jointData
end

--[=[
	Updates the ragdoll configuration.
	
	@param config RagdollConfig
]=]
function Human.SetConfig(self: any, config: RagdollConfig)
	self.Config = config
end

--[=[
	Returns whether the character is alive (Humanoid health > 0 and character exists).
	
	@return boolean
]=]
function Human.IsAlive(self: any): boolean
	if self._destroyed then
		return false
	end

	if not self.Character or not self.Character.Parent then
		return false
	end

	if not self.Humanoid or self.Humanoid.Health <= 0 then
		return false
	end

	return true
end

--[=[
	Clears any existing angular velocity and dampens linear velocity on all
	character parts to prevent wild spinning when ragdoll activates.
	@private
]=]
function Human._DampenPartVelocities(self: any)
	for _, descendant in self.Character:GetDescendants() do
		if descendant:IsA("BasePart") then
			-- Zero out angular velocity to stop any spinning
			descendant.AssemblyAngularVelocity = Vector3.zero
			-- Preserve some linear velocity for natural momentum, but cap it
			local linearVel = descendant.AssemblyLinearVelocity
			local speed = linearVel.Magnitude
			if speed > 30 then
				descendant.AssemblyLinearVelocity = linearVel.Unit * 30
			end
		end
	end
end

--[=[
	Enables ragdoll physics on the character.
	Disables Motor6D joints and replaces them with BallSocketConstraints.
]=]
function Human.Ragdoll(self: any)
	if self._destroyed then
		warn("Human:Ragdoll() called on a destroyed instance")
		return
	end

	if self.IsRagdolled then
		return
	end

	self.IsRagdolled = true

	-- Store original humanoid states
	self._originalStates.WalkSpeed = self.Humanoid.WalkSpeed
	self._originalStates.JumpPower = self.Humanoid.JumpPower
	self._originalStates.JumpHeight = self.Humanoid.JumpHeight
	self._originalStates.AutoRotate = self.Humanoid.AutoRotate
	self._originalStates.PlatformStand = self.Humanoid.PlatformStand
	self._originalStates.RequiresNeck = self.Humanoid.RequiresNeck

	-- Disable humanoid movement
	self.Humanoid.WalkSpeed = 0
	self.Humanoid.JumpPower = 0
	self.Humanoid.JumpHeight = 0
	self.Humanoid.AutoRotate = false
	self.Humanoid.PlatformStand = true
	self.Humanoid.RequiresNeck = false

	-- Change humanoid state to Physics (ragdoll)
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Set up no-collision constraints between limbs to prevent self-collision jitter
	self:_SetupNoCollision()

	for _, part in self.Character:GetDescendants() do
		if part.Name == "Torso" then
			part.AssemblyLinearVelocity = Vector3.new(RandomModule.GetRandom(), 0.0000001, RandomModule.GetRandom()).unit
					* 5
				+ (Vector3.new(0, 0.15, 0))
		end

		if part.Name == "HumanoidRootPart" then
			part:ApplyAngularImpulse(Vector3.new(-90, 0, 0))
		end
	end

	-- Replace Motor6Ds with BallSocketConstraints
	for _, jointData: JointData in self._jointData do
		local motor = jointData.Motor6D
		local part0 = jointData.Part0
		local part1 = jointData.Part1

		-- Create attachments at the joint positions
		-- Use only the positional component of C0/C1 for the attachment CFrame,
		-- and align the constraint axes properly to prevent orientation snapping
		local attachment0 = Instance.new("Attachment")
		attachment0.Name = "RagdollAttachment0"
		attachment0.CFrame = jointData.C0
		attachment0.Parent = part0

		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "RagdollAttachment1"
		attachment1.CFrame = jointData.C1
		attachment1.Parent = part1

		-- Create BallSocketConstraint
		local ballSocket = Instance.new("BallSocketConstraint")
		ballSocket.Name = "RagdollBallSocket"
		ballSocket.Attachment0 = attachment0
		ballSocket.Attachment1 = attachment1
		ballSocket.LimitsEnabled = true
		ballSocket.TwistLimitsEnabled = true

		-- Apply joint-specific limits
		local jointName = motor.Name
		local limits = JOINT_LIMITS[jointName]
		ballSocket.UpperAngle = limits.UpperAngle
		ballSocket.TwistLowerAngle = limits.TwistLowerAngle
		ballSocket.TwistUpperAngle = limits.TwistUpperAngle

		-- Apply friction torque to resist free spinning — this is critical
		-- for realistic ragdoll. Without friction, limbs spin freely like a windmill.
		ballSocket.MaxFrictionTorque = limits.MaxFrictionTorque

		ballSocket.Parent = part0

		-- Store references for cleanup
		jointData.BallSocket = ballSocket
		jointData.Attachment0 = attachment0
		jointData.Attachment1 = attachment1

		table.insert(self._ragdollConstraints, ballSocket)
		table.insert(self._ragdollConstraints, attachment0)
		table.insert(self._ragdollConstraints, attachment1)

		-- Disable the Motor6D
		motor.Enabled = false
	end

	-- Dampen velocities AFTER disabling motors to prevent wild spinning
	self:_DampenPartVelocities()

	-- Handle root part collision
	if self.RootPart then
		self.RootPart.CanCollide = false

		-- Keep root part from colliding while ragdolled, and continuously
		-- dampen excessive angular velocity on all parts to prevent spinning
		local connection = RunService.Heartbeat:Connect(function()
			if self.IsRagdolled and self.RootPart and self.RootPart.Parent then
				self.RootPart.CanCollide = false

				-- Continuously dampen angular velocity on all parts to prevent
				-- accumulated spin from collisions/physics solver instability
				for _, descendant in self.Character:GetDescendants() do
					if descendant:IsA("BasePart") then
						local angVel = descendant.AssemblyAngularVelocity
						local angSpeed = angVel.Magnitude
						-- If angular velocity exceeds a reasonable threshold, dampen it
						if angSpeed > 5.5 then
							descendant.AssemblyAngularVelocity = angVel * 0.8
						end
					end
				end
			end
		end)
		self._connections:Add(connection)
	end

	-- Auto-unragdoll after duration if configured
	if self.Config.RagdollDuration then
		task.delay(self.Config.RagdollDuration, function()
			if not self._destroyed and self.IsRagdolled then
				self:Unragdoll()
			end
		end)
	end
end

--[=[
	Disables ragdoll physics and restores normal character movement.
]=]
function Human.Unragdoll(self: any)
	if self._destroyed then
		warn("Human:Unragdoll() called on a destroyed instance")
		return
	end

	if not self.IsRagdolled then
		return
	end

	self.IsRagdolled = false

	-- Disconnect heartbeat connections
	self._connections:Remove()
	-- Remove all ragdoll constraints (BallSockets and Attachments)
	for _, constraint in self._ragdollConstraints do
		if constraint and constraint.Parent then
			constraint:Destroy()
		end
	end
	table.clear(self._ragdollConstraints)

	-- Remove no-collision constraints
	for _, noCollision in self._noCollisionConstraints do
		if noCollision and noCollision.Parent then
			noCollision:Destroy()
		end
	end
	table.clear(self._noCollisionConstraints)

	-- Clear stored constraint references from joint data and re-enable motors
	for _, jointData: JointData in self._jointData do
		jointData.BallSocket = nil
		jointData.Attachment0 = nil
		jointData.Attachment1 = nil

		-- Re-enable the Motor6D
		jointData.Motor6D.Enabled = true
	end

	-- Zero out velocities before restoring control to prevent jerky recovery
	for _, descendant in self.Character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Restore humanoid states
	if self._originalStates.WalkSpeed then
		self.Humanoid.WalkSpeed = self._originalStates.WalkSpeed
	end
	if self._originalStates.JumpPower then
		self.Humanoid.JumpPower = self._originalStates.JumpPower
	end
	if self._originalStates.JumpHeight then
		self.Humanoid.JumpHeight = self._originalStates.JumpHeight
	end
	if self._originalStates.AutoRotate ~= nil then
		self.Humanoid.AutoRotate = self._originalStates.AutoRotate
	end
	if self._originalStates.RequiresNeck ~= nil then
		self.Humanoid.RequiresNeck = self._originalStates.RequiresNeck
	end

	self.Humanoid.PlatformStand = false

	-- Restore root part collision
	if self.RootPart then
		self.RootPart.CanCollide = true
	end

	-- Re-enable humanoid states that were disabled for ragdoll
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)

	-- Return to normal humanoid state
	self.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

--[=[
	Toggles ragdoll state on or off.
]=]
function Human.ToggleRagdoll(self: any)
	if self.IsRagdolled then
		self:Unragdoll()
	else
		self:Ragdoll()
	end
end

--[=[
	Sets up NoCollisionConstraints between character limbs to prevent
	self-collision jitter during ragdoll.
	@private
]=]
function Human._SetupNoCollision(self: any)
	local parts: { BasePart } = {}

	for _, descendant in self.Character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	-- Create NoCollisionConstraints between all pairs of parts
	for i = 1, #parts do
		for j = i + 1, #parts do
			local noCollision = Instance.new("NoCollisionConstraint")
			noCollision.Name = "RagdollNoCollision"
			noCollision.Part0 = parts[i]
			noCollision.Part1 = parts[j]
			noCollision.Parent = parts[i]
			table.insert(self._noCollisionConstraints, noCollision)
		end
	end
end

--[=[
	Applies an impulse force to the ragdolled character (e.g., for knockback effects).
	
	@param force Vector3 -- The force vector to apply
	@param position Vector3? -- Optional world position to apply force at (defaults to RootPart position)
]=]
function Human.ApplyImpulse(self: any, force: Vector3, position: Vector3?)
	if self._destroyed then
		return
	end

	if not self.RootPart or not self.RootPart.Parent then
		return
	end

	if position then
		self.RootPart:ApplyImpulseAtPosition(force, position)
	else
		self.RootPart:ApplyImpulse(force)
	end
end

--[=[
	Cleans up the Human instance, removing all ragdoll artifacts and disconnecting events.
	After calling Destroy(), the instance should not be used.
]=]
function Human.Destroy(self: any)
	if self._destroyed then
		return
	end

	self._destroyed = true

	-- Unragdoll first if currently ragdolled
	if self.IsRagdolled then
		self:Unragdoll()
	end

	-- Disconnect all connections
	self._connections:Destroy()

	-- Clear references
	table.clear(self._jointData)
	table.clear(self._ragdollConstraints)
	table.clear(self._noCollisionConstraints)
	table.clear(self._originalStates)

	self.Character = nil :: any
	self.Humanoid = nil :: any
	self.RootPart = nil :: any
end

return Human
