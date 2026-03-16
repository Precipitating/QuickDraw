local ThrowableData = {

	Dynamite = {
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 75,
		Velocity = 100,
		DetonationTime = 5,
		FragmentRange = 30,
		FragmentCount = 100,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
	},

	RainsGrenade = {
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 75,
		Velocity = 200,
		DetonationTime = 3,
		FragmentRange = 30,
		FragmentCount = 500,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
	},

	Molotov = {
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 2,
		Velocity = 150,
		DetonationTime = 0,
		EffectDuration = 5,
		FragmentRange = 20,
		FragmentCount = 100,
		ThrowSound = "ThrowProjectile",
		LandSound = "MolotovLand",
		DetonationSound = "MolotovFire",
		Type = "Spread",
		ImpactParticle = "FireExplosion",
		SpreadParticle = "Burning",
		SpreadDuration = 7,
	},
}

for _, throwable in ThrowableData do
	table.freeze(throwable)
end

table.freeze(ThrowableData)

return ThrowableData
