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
		ShotDelay = 0.35,
		Damage = 25,
		Velocity = 1250,
		MinBulletSpeed = 36,
		Cost = 0,
		DragCoefficient = 0.0008,
		ReloadTimePerBullet = 0.5,
		GunType = "Revolver",
		ShootSoundName = "RevolverShot",
		ShootNoAmmoName = "RevolverClick",
		ReloadSoundName = "RevolverReload",
		MaxSimulationDistance = 650,
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
		Damage = 35,
		Cost = 1250,
		DragCoefficient = 0.00008,
		Velocity = 2000,
		MinBulletSpeed = 36,
		ReloadTimePerBullet = 1,
		GunType = "Lever",
		MaxSimulationDistance = 1250,
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
			:MaxDistance(643)
			:MinSpeed(36)
			:Done()
			:Drag()
			:Coefficient(0.00008)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Pierce()
			:Max(1)
			:SpeedThreshold(428)
			:SpeedRetention(0.75)
			:NormalBias(0.5)
			:Filter(function(_ctx, _result, _vel)
				return pierceableMaterials[_result.Material] == true
			end)
			:Done()
			:Tumble()
			:OnPierce(true)
			:SpeedThreshold(143)
			:DragMultiplier(1.8)
			:LateralStrength(14)
			:Done()
			:GyroDrift()
			:Rate(0.7) --
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
			:Visualize(false)
			:Done()
			:Build(),
	},
	Coach = {
		MaxAmmo = 2,
		MaxAmmoStack = 3,
		ShotDelay = 1,
		Damage = 20,
		Velocity = 1196,
		Cost = 500,
		MaxSimulationDistance = 107,
		PelletsPerShot = 8,
		MinBulletSpeed = 36,
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
				return _result.Material == Enum.Material.Glass
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
			:Build(),
	},
	RoperShotgun = {
		MaxAmmo = 4,
		MaxAmmoStack = 3,
		ShotDelay = 0.5,
		Damage = 25,
		Velocity = 1250,
		Cost = 1750,
		MaxSimulationDistance = 120,
		PelletsPerShot = 10,
		MinBulletSpeed = 10,
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
				return _result.Material == Enum.Material.Glass
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
			:Build(),
	},
	CannonGun = {
		MaxAmmo = 1,
		MaxAmmoStack = 3,
		ShotDelay = 0,
		Damage = 500,
		Velocity = 1250,
		Cost = 2000,
		MaxSimulationDistance = 120,
		PelletsPerShot = 1,
		MinBulletSpeed = 50,
		ReloadTimePerBullet = 5,
		GunType = "Cannon",
		DragCoefficient = 0.0015,
		ShootSoundName = "CannonShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "CannonReload",
		GunRecoil = 500,
		CameraRecoil = 500,
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(200)
			:MinSpeed(55)
			:Done()
			:Drag()
			:Coefficient(0.035)
			:Model(Vetra.Enums.DragModel.GL)
			:SegmentInterval(0.05)
			:Done()
			:Debug()
			:Visualize(true)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.CannonBallCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:HighFidelity()
			:SegmentSize(1.5)
			:FrameBudget(1)
			:Done()
			:Build(),
	},
}

for _, gun in GunData do
	table.freeze(gun)
end

table.freeze(GunData)

return GunData
