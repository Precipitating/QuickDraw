local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local isServer = game:GetService("RunService"):IsServer()
local ThrowableData = {
	Dynamite = {
		Name = "Dynamite",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 20,
		Cost = 100,
		Velocity = 70,
		DetonationTime = 3,
		FragmentCount = 450,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
		ShrapnelSpeed = 200,
		ProjectileData = Vetra.BehaviorBuilder
			.Grenade()
			:Bounce()
			:Max(1)
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:AutoDelete(false)
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.DynamiteCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Build(),
	},

	KetchumGrenade = {
		Name = "KetchumGrenade",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 30,
		Cost = 500,
		Velocity = 150,
		DetonationTime = 0,
		FragmentCount = 300,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
		ProjectileData = Vetra.BehaviorBuilder
			.Grenade()
			:Bounce()
			:Max(0)
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:AutoDelete(false)
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.KetchumGrenadeCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Physics()
			:MinSpeed(10)
			:Done()
			:Build(),
	},

	Molotov = {
		Name = "Molotov",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 2,
		Cost = 250,
		Velocity = 80,
		DetonationTime = 0,
		EffectDuration = 5,
		FragmentCount = 300,
		ThrowSound = "ThrowProjectile",
		LandSound = "MolotovLand",
		DetonationSound = "MolotovFire",
		Type = "Spread",
		ImpactParticle = "FireExplosion",
		SpreadParticle = "Burning",
		SpreadDuration = 7,
		ProjectileData = Vetra.BehaviorBuilder
			.Grenade()
			:Bounce()
			:Max(0)
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:AutoDelete(false)
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.MolotovCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Physics()
			:MinSpeed(8)
			:Done()
			:Build(),
	},
}

-- for _, throwable in ThrowableData do
-- 	table.freeze(throwable)
-- end

-- table.freeze(ThrowableData)

return ThrowableData
