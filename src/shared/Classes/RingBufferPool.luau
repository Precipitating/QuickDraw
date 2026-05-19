local RingBufferPool = {}
RingBufferPool.__index = RingBufferPool
local MIN_DISTANCE = 1
function RingBufferPool.new(template: Instance | {}, capacity: number, parent: Instance)
	local self = setmetatable({}, RingBufferPool)

	self._capacity = capacity
	self._head = 0
	self._objects = table.create(capacity)
	self._active = table.create(capacity)
	if type(template) == "table" then
		local effectCount = #template
		for i = 1, capacity do
			-- pick a random effect from the template table per slot
			local effect = template[math.random(effectCount)]
			local clone = effect:Clone()
			clone.Parent = parent
			self._objects[i] = clone
			self._active[i] = false
		end
	else
		for i = 1, capacity do
			local clone = template:Clone()
			clone.Parent = parent
			self._objects[i] = clone
			self._active[i] = false
		end
	end

	return self
end
function RingBufferPool:IsPositionOccupied(position: Vector3): boolean
	for i = 1, self._capacity do
		if self._active[i] then
			local obj = self._objects[i]
			if obj and (obj.Position - position).Magnitude < MIN_DISTANCE then
				return true
			end
		end
	end
	return false
end
function RingBufferPool:Acquire(position: Vector3?): (Instance?, number?)
	if position and self:IsPositionOccupied(position) then
		return nil, nil
	end
	self._head = (self._head % self._capacity) + 1
	self._active[self._head] = true
	return self._objects[self._head], self._head
end

function RingBufferPool:Release(index: number)
	self._active[index] = false
end

function RingBufferPool:ReleaseAll()
	for i = 1, self._capacity do
		self._active[i] = false
	end
	self._head = 0
end

function RingBufferPool:Get(index: number): Instance?
	return if self._active[index] then self._objects[index] else nil
end

function RingBufferPool:IsActive(index: number): boolean
	return self._active[index]
end

function RingBufferPool:Destroy()
	for i = 1, self._capacity do
		self._objects[i]:Destroy()
	end
	table.clear(self._objects)
	table.clear(self._active)
end

return RingBufferPool
