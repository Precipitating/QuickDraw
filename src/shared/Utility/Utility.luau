return {
	SumNumberTable = function(tbl: {})
		local sum = 0
		for _, num in pairs(tbl) do
			sum += num
		end

		return sum
	end,

	-- parent - starting instance
	-- varargs - list of path names to traverse
	GetInstance = function(parent: Instance, waitForChild: boolean, ...)
		local current: Instance = parent
		local paths = table.pack(...)

		for i = 1, paths.n do
			local name = paths[i]

			local nextInstance: Instance?

			if waitForChild then
				nextInstance = current:WaitForChild(name, 10)
			else
				nextInstance = current:FindFirstChild(name)
			end

			if not nextInstance then
				error(`[GetInstance] Cannot grab "{name}" reference`)
			end

			current = nextInstance
		end

		return current
	end,
}
