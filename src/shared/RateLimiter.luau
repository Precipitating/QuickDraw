-- RateLimiter.lua
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxPerSecond: number)
	return setmetatable({
		MaxPerSecond = maxPerSecond,
		Calls = 0,
		WindowStart = os.clock(),
	}, RateLimiter)
end

function RateLimiter:TryConsume(): boolean
	local now = os.clock()
	if now - self.WindowStart >= 1 then
		self.WindowStart = now
		self.Calls = 0
	end

	if self.Calls >= self.MaxPerSecond then
		return false
	end

	self.Calls += 1
	return true
end

return RateLimiter
