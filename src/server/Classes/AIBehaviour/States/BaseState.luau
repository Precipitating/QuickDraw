local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local BaseState = {}
BaseState.__index = BaseState

-- Base class that defines the functions that may be inherited by subclass
function BaseState.new(machine, ai)
	local self = setmetatable({}, BaseState)
	self.Machine = machine
	self.Name = "Unnamed"
	self.AI = ai
	self.Human = ai.Owner
	self.Janitor = Janitor.new()
	return self
end

-- Called once when state object is created
function BaseState:Init() end

-- Called when entering state
function BaseState:Enter(previousState, data) end

-- Called every frame (if enabled)
function BaseState:Update(dt) end

-- Called when exiting state
function BaseState:Exit(nextState) end

-- Optional transition guard
function BaseState:CanTransition(toStateName)
	local currentState = self.Machine:GetState()
	if currentState == "Dead" then
		return false
	end
	if not self.AI or not self.AI.NoobPath or not self.Human then
		return false
	end

	return true
end

-- Cleanup helper
function BaseState:Cleanup()
	self.Janitor:Cleanup()
end

return BaseState
