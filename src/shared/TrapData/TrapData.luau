local TrapData = {
	BearTrap = {
		Name = "BearTrap",
		MaxAmmo = 1,
		MaxAmmoStack = 1,
		Cost = 200,
		Damage = 55,
		HoldTime = 3,
		PlaceSoundName = "BearTrapPlaced",
		TrapActivatedSoundName = "BearTrapActivated",
	},
	TripMine = {
		Name = "TripMine",
		Disguise = true,
		AttachedExplosive = "KetchumGrenade",
		MaxAmmo = 1,
		MaxAmmoStack = 1,
		Damage = 100,
		Cost = 750,
		HoldTime = 3,
		PlaceSoundName = "TripMinePlaced",
		TrapActivatedSoundName = "TripMineActivated",
	},
	RopeTrap = {
		Name = "RopeTrap",
		MaxAmmo = 1,
		MaxAmmoStack = 1,
		Damage = 10,
		Cost = 100,
		HoldTime = 3,
		Duration = 5,
		CeilingDistance = 50,
		PlaceSoundName = "RopeTrapPlaced",
		TrapActivatedSoundName = "RopeTrapActivated",
	},
}
for _, gun in TrapData do
	table.freeze(gun)
end

table.freeze(TrapData)

return TrapData
