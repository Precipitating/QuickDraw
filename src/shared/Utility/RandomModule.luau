local rng = Random.new()
return {
	GetRandomIntBetween = function(min: number, max: number)
		return rng:NextInteger(min, max)
	end,
	GetRandomDecimalBetween = function(min: number, max: number)
		return rng:NextNumber(min, max)
	end,

	-- 0 - 1 decimal
	GetRandom = function()
		return rng:NextNumber()
	end,
}
