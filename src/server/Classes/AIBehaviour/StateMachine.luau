local RunService = game:GetService("RunService")

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
	local self = setmetatable({}, StateMachine)

	self.States = {}
	self.CurrentState = nil
	self.CurrentStateName = nil
	self.PreviousState = nil

	self._updating = false
	self._connection = nil

	return self
end

-- Register a state
function StateMachine:AddState(name, stateObject)
	assert(self.States[name] == nil, "State already exists: " .. name)
	self.States[name] = stateObject
	stateObject.Name = name
	stateObject:Init()
end

-- Start updating loop
function StateMachine:Start()
	if self._updating then
		return
	end
	self._updating = true

	self._connection = RunService.Heartbeat:Connect(function(dt)
		if self.CurrentState and self.CurrentState.Update then
			self.CurrentState:Update(dt)
		end
	end)
end

-- Stop updating
function StateMachine:Stop()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self._updating = false
end

-- Transition logic
function StateMachine:Transition(toStateName, data)
	local newState = self.States[toStateName]
	assert(newState, "State does not exist: " .. tostring(toStateName))

	if self.CurrentState then
		if not self.CurrentState:CanTransition(toStateName) then
			return false
		end

		self.CurrentState:Exit(toStateName)
		self.CurrentState:Cleanup()
	end

	self.PreviousState = self.CurrentState
	self.CurrentState = newState
	self.CurrentStateName = toStateName

	newState:Enter(self.PreviousState and self.PreviousState.Name, data)

	return true
end

-- Getters
function StateMachine:GetState()
	return self.CurrentStateName
end

function StateMachine:GetPreviousState()
	return self.PreviousState and self.PreviousState.Name
end

return StateMachine
