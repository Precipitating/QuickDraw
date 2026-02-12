local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

export type Human = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	IsRagdolled: boolean,

	Ragdoll: (self: Human) -> (),
	UnRagdoll: (self: Human) -> (),
	ToggleRagdoll: (self: Human) -> (),
	IsAlive: (self: Human) -> boolean,
	Destroy: (self: Human) -> (),
	OnDeath: (self: Human) -> (),
}

local RagdollDisabledStates = {
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local CharacterStates = {
	Ragdoll = Enum.HumanoidStateType.Ragdoll,
	Falling = Enum.HumanoidStateType.FallingDown,
	GettingUp = Enum.HumanoidStateType.GettingUp,
	Dead = Enum.HumanoidStateType.Dead,
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
function Human.new(player: Player?): Human
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
	self.Humanoid = humanoid :: Humanoid?
	self.RootPart = rootPart :: BasePart
	self.IsRagdolled = false
	self.Janitor = Janitor.new()
	self.AnimationControllerState = false

	-- keep BallSocketConstraints on death
	humanoid.BreakJointsOnDeath = false
	-- avoid HRP colliding with UpperTorso on death
	character.HumanoidRootPart.CanCollide = false

	self:OnHumanoidStateChange()

	print(`New Human class initialized for {self.Player.DisplayName}`)

	return self :: any
end

function Human:OnHumanoidStateChange()
	if not self.Humanoid then
		error("Missing humanoid reference in human class!")
	end

	-- disable joints when falling
	self.Janitor:Add(
		self.Humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
			if RagdollDisabledStates[newState] then
				self.AnimationControllerState = false
			else
				self.AnimationControllerState = true
			end

			print(newState)
			for _, j in self.Character:GetDescendants() do
				if j:IsA("AnimationConstraint") and j.Name ~= "Root" then
					j.Enabled = self.AnimationControllerState
				end
			end
		end)
	)
end
--[=[
	Creates a Human instance from a Player. Waits for the character if it hasn't loaded yet.
	
	@param player Player -- The player to create a Human from
	@param config RagdollConfig? -- Optional configuration
	@return Human
]=]
function Human.FromPlayer(player: Player): Human
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")

	return Human.new(player)
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

function Human:Ragdoll()
	self.Humanoid:ChangeState(CharacterStates["Ragdoll"])
	self.Humanoid:SetStateEnabled(CharacterStates["GettingUp"], false)
	print(`{self.Player.DisplayName} should ragdoll`)
end

function Human:UnRagdoll()
	self.Humanoid:SetStateEnabled(CharacterStates["GettingUp"], true)
	print(`{self.Player.DisplayName} should get up`)
end

--[=[
	Applies death ragdoll state
]=]
function Human:OnDeath()
	for _, joint in self.Character:GetDescendants() do
		if joint:IsA("AnimationConstraint") then
			joint.Enabled = false
		elseif joint:IsA("BallSocketConstraint") then
			joint.MaxFrictionTorque = 10
		end
	end

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

function Human:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	-- Unragdoll first if currently ragdolled
	if self.IsRagdolled then
		self:Unragdoll()
	end

	-- Disconnect all connections
	self.Janitor:Destroy()

	self.Humanoid = nil :: any
	self.Player = nil
	self.Character = nil
	self.Humanoid = nil
	self.RootPart = nil
	self.IsRagdolled = nil
	self.Janitor = nil
	self.AnimationControllerState = nil
	setmetatable(self, nil)
	print(`Human class destroyed!`)
end

return Human
