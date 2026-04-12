local Stack = {}
Stack.__index = Stack

export type Stack<T> = {
	_stack: { T },
	IsEmpty: (self: Stack<T>) -> boolean,
	Push: (self: Stack<T>, value: T) -> (),
	Pop: (self: Stack<T>) -> T?,
	Peek: (self: Stack<T>) -> T?,
}

function Stack.new()
	local self = setmetatable({}, Stack)

	self._stack = {}

	return self
end

-- Check if the stack is empty
function Stack:IsEmpty()
	return #self._stack == 0
end

-- Put a new value onto the stack
function Stack:Push(value)
	table.insert(self._stack, value)
end

function Stack:Peek()
	if self:IsEmpty() then
		return nil
	end

	return self._stack[#self._stack]
end

-- Take a value off the stack
function Stack:Pop()
	if self:IsEmpty() then
		return nil
	end

	return table.remove(self._stack, #self._stack)
end

return Stack
