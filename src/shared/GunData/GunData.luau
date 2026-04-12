local GunData = {
	Revolver = {
		MaxAmmo = 6,
		ShotDelay = 0.35,
		Damage = 25,
		Velocity = 900,
		ReloadTimePerBullet = 0.5,
		GunType = "Revolver",
		ShootSoundName = "RevolverShot",
		ShootNoAmmoName = "RevolverClick",
		ReloadSoundName = "RevolverReload",
		GunRecoil = 50,
		CameraRecoil = 20,
	},
	Winchester = {
		MaxAmmo = 13,
		ShotDelay = 0.8,
		Damage = 35,
		Cost = 15000,
		Velocity = 2000,
		ReloadTimePerBullet = 1,
		GunType = "Lever",
		ShootSoundName = "WinchesterShot",
		ShootNoAmmoName = "RevolverClick",
		LoadNextRoundName = "WinchesterLoadBullet",
		ReloadSoundName = "WinchesterReload",
		GunRecoil = 38,
		CameraRecoil = 12,
	},
	Coach = {
		MaxAmmo = 2,
		ShotDelay = 1,
		Damage = 20,
		Velocity = 450,
		Cost = 7500,
		PelletsPerShot = 8,
		MaxSpreadAngle = 8,
		ReloadTimePerBullet = 1,
		GunType = "Shotgun",
		ShootSoundName = "CoachShot",
		ShootNoAmmoName = "CoachClick",
		ReloadSoundName = "CoachReload",
		GunRecoil = 100,
		CameraRecoil = 80,
	},
}

for _, gun in GunData do
	table.freeze(gun)
end

table.freeze(GunData)

return GunData
