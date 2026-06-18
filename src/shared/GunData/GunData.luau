local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(script.Parent.Parent.Vetra)
local pierceableMaterials = {
	[Enum.Material.Glass] = true,
	[Enum.Material.Ice] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}

local GunData = {
	Revolver = {
		MaxAmmo = 6,
		MaxAmmoStack = 3,
		ShotDelay = 0.25,
		Damage = 25,
		Velocity = 1250,
		Description = "The reliable 6 shot revolver (25 damage)",
		Cost = 0,
		RefillCost = 0,
		DragCoefficient = 0.0008,
		ReloadTimePerBullet = 0.5,
		GunType = "Revolver",
		ShootSoundName = "RevolverShot",
		ShootNoAmmoName = "RevolverClick",
		ReloadSoundName = "RevolverReload",
		MaxSimulationDistance = 1250,
		GunRecoil = 50,
		CameraRecoil = 20,
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MinSpeed(36)
			:Done()
			:Drag()
			:Coefficient(0.0008)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1)
			:SpeedThreshold(321)
			:SpeedRetention(0.65)
			:NormalBias(0.4)
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:OnPierce(true)
			:SpeedThreshold(214)
			:DragMultiplier(2.0)
			:LateralStrength(21)
			:Done()
			:HighFidelity()
			:SegmentSize(0.5)
			:FrameBudget(1)
			:Done()
			:Debug()
			:Visualize(false)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:Build(),
	},
	Winchester = {
		MaxAmmo = 8,
		MaxAmmoStack = 3,
		ShotDelay = 0.8,
		Damage = 50,
		Cost = 1250,
		RefillCost = 100,
		DragCoefficient = 0.00008,
		Velocity = 2000,
		Description = "A strong 8 shot lever action rifle (50 damage)",
		ReloadTimePerBullet = 1,
		GunType = "Lever",
		MaxSimulationDistance = 2000,
		ShootSoundName = "WinchesterShot",
		ShootNoAmmoName = "RevolverClick",
		LoadNextRoundName = "WinchesterLoadBullet",
		ReloadSoundName = "WinchesterReload",
		GunRecoil = 38,
		CameraRecoil = 12,
		ProjectileData = Vetra
			.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(350)
			:MinSpeed(260)
			:Done()
			:Drag()
			:Coefficient(0.005)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1)
			:SpeedThreshold(80)
			:SpeedRetention(0.75)
			:NormalBias(0.5)
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:OnPierce(true)
			:SpeedThreshold(60)
			:DragMultiplier(2.0)
			:LateralStrength(14)
			:Done()
			:GyroDrift()
			:Rate(0.4) -- shorter barrel, less rifling twist than a rifle
			:Done()
			:HighFidelity()
			:SegmentSize(0.4)
			:FrameBudget(1)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:Debug()
			:Visualize(true)
			:Done()
			:Build(),
	},
	Coach = {
		MaxAmmo = 2,
		MaxAmmoStack = 3,
		ShotDelay = 1,
		Damage = 20,
		Velocity = 1196,
		Description = "A double barreled shotgun, doing devastating damage up close (8 pellets a shot) (20 damage per pellet)",
		Cost = 500,
		RefillCost = 100,
		MaxSimulationDistance = 107,
		PelletsPerShot = 8,
		MaxSpreadAngle = 8,
		ReloadTimePerBullet = 2,
		GunType = "Shotgun",
		DragCoefficient = 0.002,
		ShootSoundName = "CoachShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "CoachReload",
		GunRecoil = 100,
		CameraRecoil = 80,
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(107)
			:MinSpeed(36)
			:Done()
			:Drag()
			:Coefficient(0.002)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1)
			:SpeedThreshold(214)
			:SpeedRetention(0.5)
			:NormalBias(0.3)
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:OnPierce(true)
			:SpeedThreshold(143)
			:DragMultiplier(2.5)
			:LateralStrength(36)
			:Done()
			:Fragmentation()
			:OnPierce(true)
			:Count(3)
			:Deviation(25)
			:Done()
			:Debug()
			:Visualize(false)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:HighFidelity()
			:SegmentSize(0.6)
			:FrameBudget(1)
			:Done()
			:BatchTravel(true)
			:Build(),
	},
	RoperShotgun = {
		MaxAmmo = 4,
		JamChance = 0.05,
		MaxAmmoStack = 3,
		ShotDelay = 0.5,
		Damage = 25,
		Velocity = 1250,
		Description = "A repeating 4 shot shotgun (25 damage per pellet) (10 pellets a shot)",
		Cost = 1750,
		RefillCost = 200,
		MaxSimulationDistance = 120,
		PelletsPerShot = 10,
		MaxSpreadAngle = 6,
		ReloadTimePerBullet = 3,
		GunType = "Shotgun",
		DragCoefficient = 0.0015,
		ShootSoundName = "CoachShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "CoachReload",
		GunRecoil = 75,
		CameraRecoil = 60,
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(120)
			:MinSpeed(36)
			:Done()
			:Drag()
			:Coefficient(0.002)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1)
			:SpeedThreshold(214)
			:SpeedRetention(0.5)
			:NormalBias(0.3)
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:OnPierce(true)
			:SpeedThreshold(143)
			:DragMultiplier(2.5)
			:LateralStrength(36)
			:Done()
			:Fragmentation()
			:OnPierce(true)
			:Count(3)
			:Deviation(25)
			:Done()
			:Debug()
			:Visualize(false)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:HighFidelity()
			:SegmentSize(0.6)
			:FrameBudget(1)
			:Done()
			:BatchTravel(true)
			:Build(),
	},
	CannonGun = {
		MaxAmmo = 1,
		MaxAmmoStack = 3,
		ShotDelay = 0,
		Damage = 500,
		Velocity = 1000,
		Description = "An experimental 1 shot hand cannon (500 damage)",
		Cost = 2000,
		RefillCost = 200,
		MaxSimulationDistance = 900,
		PelletsPerShot = 1,
		ReloadTimePerBullet = 5,
		GunType = "Cannon",
		DragCoefficient = 0.0015,
		ShootSoundName = "CannonShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "CannonReload",
		GunRecoil = 500,
		CameraRecoil = 500,
		ProjectileData = Vetra
			.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(900) -- cannonballs carry serious range
			:MinSpeed(30) -- dense ball keeps rolling even when slowed
			:BulletMass(0.9) -- ~900g, miniature iron cannonball
			:Done()
			:Drag()
			:Coefficient(0.045) -- sphere has higher Cd, but mass compensates
			:Model(Vetra.Enums.DragModel.GL) -- GL is correct here, it's designed for spherical projectiles
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(2) -- punches through barrels, wood walls, light cover
			:SpeedThreshold(80) -- needs momentum to punch through
			:SpeedRetention(0.8) -- barely slows, it's iron and heavy
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Bounce()
			:Max(3) -- cannonballs skip and roll historically
			:Restitution(0.35) -- low bounce height, it's not rubber
			:SpeedThreshold(20) -- stops bouncing when nearly halted
			:NormalPerturbation(0.04) -- slight surface irregularity on each bounce
			:Done()
			:CornerTrap() -- prevents ball getting wedged in geometry during bouncing
			:Done()
			:Wind()
			:Response(0.15) -- nearly immune to wind, it's a dense iron ball
			:Done()
			:Debug()
			:Visualize(true)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.CannonBallCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:HighFidelity()
			:SegmentSize(0.8) -- finer than original for accurate bounce resolution
			:FrameBudget(3) -- single shot weapon, can afford the budget
			:Done()
			:Build(),
	},
	Gatling = {
		MaxAmmo = 20,
		MaxAmmoStack = 3,
		ShotDelay = 0.3,
		Damage = 20,
		Velocity = 2250,
		Description = "An early version of automatic weaponry. Lever cranked gatling (20 damage)",
		Cost = 5000,
		RefillCost = 300,
		MaxSimulationDistance = 600,
		ReloadTime = 3,
		GunType = "Automatic",
		DragCoefficient = 0.0015,
		ShootSoundName = "GatlingShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "GatlingReload",
		GunRecoil = 50,
		CameraRecoil = 50,
		ProjectileData = Vetra
			.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(600) -- gatling isn't long-range; ~600 studs is realistic
			:MinSpeed(50) -- let bullets fully travel before culling
			:BulletMass(0.028) -- ~28g, typical .45-70 Government round
			:Done()
			:Drag()
			:Coefficient(0.035) -- heavy lead slug, moderate drag over distance
			:Model(Vetra.Enums.DragModel.G7) -- G7 fits elongated flat-base bullets better than GL (GL = grenades/spherical)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1) -- punches through one thin surface (wood planks, barrels)
			:SpeedThreshold(120) -- needs momentum to pierce
			:SpeedRetention(0.65) -- loses significant speed going through material
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:SpeedThreshold(80) -- soft lead tumbles when slowed
			:DragMultiplier(3.5) -- tumbling bleeds speed fast
			:LateralStrength(0.4) -- visible wobble path
			:OnPierce(true) -- always tumbles after punching through something
			:Done()
			:Wind()
			:Response(0.5) -- open frontier battlefields, noticeable crosswind
			:Done()
			:GyroDrift()
			:Rate(0.006) -- subtle right-hand drift from rifled barrels
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:HighFidelity()
			:SegmentSize(0.4) -- finer than before for accurate tumble/pierce resolution
			:FrameBudget(4) -- gatling fires many bullets at once, needs more budget
			:Done()
			:BatchTravel(true) -- batch OnTravel events since many rounds are in-flight simultaneously
			:Debug()
			:Visualize(true)
			:Done()
			:Build(),
	},
}

for _, gun in GunData do
	table.freeze(gun)
end

table.freeze(GunData)

return GunData
