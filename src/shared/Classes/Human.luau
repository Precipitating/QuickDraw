local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)

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
	self.Humanoid = humanoid
	self.RootPart = rootPart :: BasePart
	self.IsRagdolled = false

	return self :: any
end

--[=[
	Creates a Human instance from a Player. Waits for the character if it hasn't loaded yet.
	
	@param player Player -- The player to create a Human from
	@param config RagdollConfig? -- Optional configuration
	@return Human
]=]
function Human.fromPlayer(player: Player): Human
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

function Human.Ragdoll(self: any) end

function Human.Unragdoll(self: any) end

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

	self.Character = nil :: any
	self.Humanoid = nil :: any
end

return Human
