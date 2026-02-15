return {
	SumNumberTable = function(tbl: {})
		local sum = 0
		for _, num in pairs(tbl) do
			sum += num
		end

		return sum
	end,
}
