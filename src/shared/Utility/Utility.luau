return {
	SumNumberTable = function(tbl: {})
		local sum = 0
		for _, num in tbl do
			sum += num
		end

		return sum
	end,

	IsVectorNear = function(vector: Vector3, threshold: number)
		threshold = threshold or 0.01
		return vector.Magnitude < threshold
	end,

	-- parent - starting instance
	-- varargs - list of path names to traverse
	GetInstance = function(parent: Instance, waitForChild: boolean, ...)
		local current: Instance = parent
		local paths = table.pack(...)

		if not current then
			return nil
		end

		for i = 1, paths.n do
			local name = paths[i]

			local nextInstance: Instance?

			if waitForChild then
				nextInstance = current:WaitForChild(name, 10)
			else
				nextInstance = current:FindFirstChild(name, true)
			end

			if not nextInstance then
				warn(`[GetInstance] Cannot grab "{name}" reference`)
				return nil
			end

			current = nextInstance
		end

		return current
	end,
}
