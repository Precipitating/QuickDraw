local GunData = {
	Revolver = {
		MaxAmmo = 999,
		ShotDelay = 0.35,
		Damage = 30,
		Velocity = 900,
		ShootSoundName = "RevolverShot",
		ShootNoAmmoName = "RevolverClick",
		GunRecoil = 50,
		CameraRecoil = 20,
	},
}

for _, gun in GunData do
	table.freeze(gun)
end

table.freeze(GunData)

return GunData
