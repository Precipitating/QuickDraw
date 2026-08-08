local Players = game:GetService("Players")

local DEBUG_PRINT = true

local _print = print
local _warn = warn
local _error = error

local RandomModule = require(script.Parent.RandomModule)
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
		local caller = debug.info(2, "sln") -- source, line, name of the calling function
		local tag = `[GetInstance ← {caller}]`

		local current: Instance = parent
		local paths = table.pack(...)

		if not current then
			warn(`{tag} Parent is nil`)
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
				warn(`{tag} Cannot find "{name}" under "{current:GetFullName()}"`)
				return nil
			end

			current = nextInstance
		end

		return current
	end,

	GetShotgunSpreadDirection = function(baseDirection: Vector3, maxDegrees: number)
		-- Use a circular spread pattern
		-- Pick a random angle and random radius within the cone
		local angle = RandomModule.GetRandom() * 2 * math.pi
		local radius = math.sqrt(RandomModule.GetRandom()) * math.rad(maxDegrees)

		local randomX = math.cos(angle) * radius
		local randomY = math.sin(angle) * radius

		local spreadCFrame = CFrame.new(Vector3.zero, baseDirection) * CFrame.Angles(randomX, randomY, 0)

		return spreadCFrame.LookVector
	end,

	IsHoldingTool = function(character: Model, name: string)
		if not character then
			return false
		end

		local holdingTool = character:FindFirstChild(name)

		return holdingTool
	end,

	GetClosePlayers = function(position: Vector3, maxDistance: number): { Player }
		local relevant = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - position).Magnitude <= maxDistance then
				table.insert(relevant, player)
			end
		end
		return relevant
	end,

	Log = function(...)
		if DEBUG_PRINT then
			_print(...)
		end
	end,

	Warn = function(...)
		if DEBUG_PRINT then
			_warn(...)
		end
	end,

	Error = function(...)
		if DEBUG_PRINT then
			_error(...)
		end
	end,
}
