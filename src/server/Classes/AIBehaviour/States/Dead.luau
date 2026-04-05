local BaseState = require(script.Parent.BaseState)

local Dead = setmetatable({}, BaseState)
Dead.__index = Dead

function Dead.new(machine, ai)
	local self = BaseState.new(machine, ai)
	setmetatable(self, Dead)
	return self
end

function Dead:Enter(previous)
	warn("Entered Dead from", previous)
	self.AI:StateChangeReset()
end

function Dead:Update(dt) end

function Dead:Exit(nextState) end

return Dead
