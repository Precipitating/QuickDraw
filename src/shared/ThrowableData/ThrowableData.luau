local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local isServer = game:GetService("RunService"):IsServer()
local ThrowableData = {
	Dynamite = {
		Name = "Dynamite",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 40,
		Cost = 100,
		Velocity = 80,
		Description = "A loaded timed explosive of 3 seconds, doing 40 damage a pellet with 450 fragment counts.",
		DetonationTime = 3,
		FragmentCount = 450,
		BlastRadius = 10,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
		ShrapnelSpeed = 200,
		ProjectileData = Vetra
			.BehaviorBuilder
			.Grenade()
			:Clone() -- branch off the preset rather than mutating it
			:Physics()
			:MaxDistance(150) -- shorter realistic throw range than a grenade lob
			:MinSpeed(2)
			:Done()
			:Bounce()
			:Max(2) -- a couple of dull thumps, not a lively bounce
			:Restitution(0.2) -- low restitution: dynamite doesn't bounce much
			:SpeedThreshold(8) -- stops bouncing once it's rolling slowly
			:NormalPerturbation(0.03)
			:Done()
			:CornerTrap()
			:TimeThreshold(0.01)
			:DisplacementThreshold(0.25)
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
		Cost = 300,
		Velocity = 150,
		Description = "A high damage throwable missile, spraying 300 fragments of shrapnel (30 damage per pellet)",
		DetonationTime = 0,
		BlastRadius = 3,
		FragmentCount = 300,
		ThrowSound = "ThrowProjectile",
		LandSound = "DynamiteFuse",
		DetonationSound = "DynamiteExplosion",
		Type = "Explosive",
		ImpactParticle = "Explosion",
		ProjectileData = Vetra
			.BehaviorBuilder
			.Grenade()
			:Clone()
			:Bounce()
			:Max(0) -- terminates on first contact, no bouncing
			:Done()
			:Physics()
			:MinSpeed(10) -- thrown with more force than a standard lob
			:MaxDistance(200)
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.KetchumGrenadeCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Build(),
	},

	Molotov = {
		Name = "Molotov",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 2,
		Cost = 200,
		Velocity = 200,
		Description = "A fire explosive, dealing 2 damage for 5 seconds to affected limb.",
		DetonationTime = 0,
		BlastRadius = 6,
		FragmentCount = 300,
		ThrowSound = "ThrowProjectile",
		LandSound = "MolotovLand",
		DetonationSound = "MolotovFire",
		Type = "Spread",
		ImpactParticle = "FireExplosion",
		SpreadParticle = "Burning",
		SpreadDuration = 5,
		ProjectileData = Vetra
			.BehaviorBuilder
			.Grenade()
			:Clone()
			:Bounce()
			:Max(0) -- shatters on first contact, no bouncing
			:Done()
			:Physics()
			:MinSpeed(8)
			:MaxDistance(120) -- shorter realistic throw than a frag grenade
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.MolotovCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Build(),
	},
	HookGrenade = {
		Name = "HookGrenade",
		MaxAmmo = 1,
		ThrowDelay = 5,
		Damage = 3,
		Cost = 300,
		Velocity = 200,
		Description = "A grenade designed to disable the player via a grapple hook explosion. Any clean connections will bind the player's limb to nearby walls.",
		DetonationTime = 3,
		BlastRadius = 3,
		FragmentCount = 100,
		ThrowSound = "ThrowProjectile",
		LandSound = "HookGrenadeLand",
		DetonationSound = "GrappleHook",
		Type = "Explosive",
		Subtype = "Hook",
		SubtypeEffectDuration = 10,
		ImpactParticle = "Explosion",
		ProjectileData = Vetra
			.BehaviorBuilder
			.Grenade()
			:Clone() -- branch off the shared preset
			:Bounce()
			:Max(1) -- one heavy thud before the mud lump settles
			:Restitution(0.15) -- mud absorbs most of the impact, barely rebounds
			:SpeedThreshold(10)
			:Done()
			:Physics()
			:MinSpeed(10)
			:MaxDistance(180)
			:Done()
			:Fragmentation()
			:Count(6) -- the embedded grappling hooks scatter on detonation
			:Deviation(35) -- wide spread angle, chaotic hook trajectories
			:OnPierce(false) -- only fragments on terminal impact, not pierce
			:Done()
			:When(isServer, function(b)
				b:Cosmetic()
					:AutoDelete(false)
					:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.HookGrenadeCosmetic)
					:Container(workspace.ProjectilesFolder)
					:Done()
			end)
			:Build(),
	},
}

for _, throwable in ThrowableData do
	table.freeze(throwable)
end

table.freeze(ThrowableData)

return ThrowableData
