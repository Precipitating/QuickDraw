local GunData = {
	Revolver = {
		MaxAmmo = 999,
		ShotDelay = 0.35,
		Damage = 30,
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
		Velocity = 1000,
		ReloadTimePerBullet = 1,
		GunType = "Lever",
		ShootSoundName = "WinchesterShot",
		ShootNoAmmoName = "RevolverClick",
		LoadNextRoundName = "WinchesterLoadBullet",
		ReloadSoundName = "WinchesterReload",
		GunRecoil = 38,
		CameraRecoil = 12,
	},
}

for _, gun in GunData do
	table.freeze(gun)
end

table.freeze(GunData)

return GunData
