export type Gun = {
	Tool: Tool?,
	MaxAmmo: number,
	CurrentAmmo: number,
	ShotDelay: number,
	ShootPoint: Attachment?,
	PlayerRef: Player?,
	CanShoot: boolean,
	CurrentCooldown: number,
	AddGunToInventory: (self: Gun) -> (),
	ShootGun: (self: Gun) -> (),
	MuzzleFlash: Attachment?,
	HumanClassRef: Human?,
}

export type Human = {
	Player: Player,
	Health: number,
	Stamina: number,
	HumanType: string,
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	IsRagdolled: boolean,
	HRP: BasePart,
	CurrentGun: Gun?,
	LimbHealth: {},
	BodyParts: {},

	Ragdoll: (self: Human) -> (),
	UnRagdoll: (self: Human) -> (),
	ToggleRagdoll: (self: Human) -> (),
	IsAlive: (self: Human) -> boolean,
	Destroy: (self: Human) -> (),
	OnDeath: (self: Human) -> (),
	DisableLimb: (self: Human, limbName: string) -> (),
	ApplyImpulse: (force: Vector3, position: Vector3?) -> (),
	ApplyImpulseOnLimb: (limbName: string, force: Vector3) -> (),
}

export type HumanPlayer = Human & {
	Player: Player,
}

return nil
