local ThrowableData = {

	Dynamite = {
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 75,
		Velocity = 150,
		DetonationTime = 3,
		FragmentRange = 60,
		FragmentCount = 60,
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
	},
}

for _, throwable in ThrowableData do
	table.freeze(throwable)
end

table.freeze(ThrowableData)

return ThrowableData
