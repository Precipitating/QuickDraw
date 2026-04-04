local BaseState = require(script.Parent.BaseState)

local Idle = setmetatable({}, BaseState)
Idle.__index = Idle

function Idle.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Idle)
	return self
end

function Idle:Enter(previous)
	print("Entered Idle from", previous)
end

function Idle:Update(dt) end

function Idle:Exit(nextState)
	print("Leaving Idle to", nextState)
end

return Idle
