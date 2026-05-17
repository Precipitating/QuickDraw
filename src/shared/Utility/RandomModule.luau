local rng = Random.new()
return {
	GetRandomIntBetween = function(min: number, max: number)
		return rng:NextInteger(min, max)
	end,
	GetRandomDecimalBetween = function(min: number, max: number)
		return rng:NextNumber(min, max)
	end,

	GetNextUnitVector = function()
		return rng:NextUnitVector()
	end,

	-- 0 - 1 decimal
	GetRandom = function()
		return rng:NextNumber()
	end,

	WeightedRandom = function(choices: { { value: any, weight: number } })
		local total = 0
		for _, entry in choices do
			total += entry.weight
		end
		local roll = rng:NextInteger(1, total)
		local cumulative = 0
		for _, entry in choices do
			cumulative += entry.weight
			if roll <= cumulative then
				return entry.value
			end
		end
		return
	end,
}
