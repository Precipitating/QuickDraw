local TrapData = {
	BearTrap = {
		MaxAmmo = 1,
		MaxAmmoStack = 1,
		Cost = 550,
		Damage = 50,
		PlaceSoundName = "BearTrapPlace",
		TrapActivatedSoundName = "BearTrapActivated",
	},
}
for _, gun in TrapData do
	table.freeze(gun)
end

table.freeze(TrapData)

return TrapData
