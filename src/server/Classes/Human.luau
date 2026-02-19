local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerSignals = require(ServerScriptService.Server.Managers.Player.PlayerSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ClassTypes = require(script.Parent.ClassTypes)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
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
	LeftUpperLeg = 65,
	LeftLowerLeg = 65,
	RightUpperLeg = 65,
	RightLowerLeg = 65,
}

local CharacterStates = {
	Ragdoll = Enum.HumanoidStateType.Ragdoll,
	Falling = Enum.HumanoidStateType.FallingDown,
	GettingUp = Enum.HumanoidStateType.GettingUp,
	Dead = Enum.HumanoidStateType.Dead,
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

	self.Health = 465
	self.Character = character
	self.Humanoid = humanoid
	self.RootPart = rootPart :: BasePart

	self.LimbHealth = table.clone(LimbHealth)
	self.BodyParts = table.clone(BodyParts)

	self.IsRagdolled = false
	self.AnimationControllerState = false

	self.CurrentGun = nil

	-- keep BallSocketConstraints on death
	humanoid.BreakJointsOnDeath = false
	-- avoid HRP colliding with UpperTorso on death
	character.HumanoidRootPart.CanCollide = false

	self:OnHumanoidStateChange()
	self:AssignBodyParts()
	self:SimulateDefaultLimbs()

	return self :: any
end

function Human:AssignBodyParts()
	for _, obj in self.Character:GetChildren() do
		if BodyParts[obj.Name] then
			obj.CanQuery = true
			self.BodyParts[obj.Name] = obj
		end
	end
end

function Human:SimulateDefaultLimbs()
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
end

function Human:DestroyLimb(limbName: string)
	self.BodyParts[limbName]:Destroy()
	self.BodyParts[limbName] = nil
	ServerSoundHandler:PlaySoundTo(nil, "LimbDismember", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })

	if not self.BodyParts["RightUpperLeg"] and not self.BodyParts["LeftUpperLeg"] then
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		print("Both legs gone")
	end
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

function Human:Ragdoll()
	self.Humanoid:ChangeState(CharacterStates["Ragdoll"])
	self.Humanoid:SetStateEnabled(CharacterStates["GettingUp"], false)
	print(`{self.Character.Name} should ragdoll`)
end

function Human:UnRagdoll()
	self.Humanoid:SetStateEnabled(CharacterStates["GettingUp"], true)
	print(`{self.Character.Name} should get up`)
end

--[=[
	Applies death ragdoll state
]=]
function Human:OnDeath()
	task.spawn(function()
		for _, joint in self.Character:GetDescendants() do
			if joint:IsA("AnimationConstraint") then
				joint.Enabled = false
			elseif joint:IsA("BallSocketConstraint") then
				joint.MaxFrictionTorque = 10
			end
		end
	end)

	self:Destroy()
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
