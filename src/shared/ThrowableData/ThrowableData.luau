local ThrowableData = {

	Dynamite = {
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 75,
		Velocity = 100,
		DetonationTime = 3,
	},
}

for _, throwable in ThrowableData do
	table.freeze(throwable)
end

table.freeze(ThrowableData)

return ThrowableData
