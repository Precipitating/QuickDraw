local TrapData = {
	BearTrap = {
		Name = "BearTrap",
		MaxAmmo = 1,
		Description = "Place one down, two foot. One step in, one foot. (55 damage)",
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
		Description = "Country roads, take me home. To the place I belong. (detonates a Ketchum Grenade on trigger) ",
		MaxAmmoStack = 1,
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
		Description = "You'll be hangin' around if you step on this! (10 damage)",
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
