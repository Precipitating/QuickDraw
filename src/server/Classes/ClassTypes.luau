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
	ShootGun: (self: Gun, adsPos: Vector3, adsDir: Vector3) -> (),
	MuzzleFlash: Attachment?,
	HumanClassRef: Human?,
}

export type Human = {
	-- Core
	Player: Player?, -- not set in constructor, so optional unless assigned elsewhere
	HumanType: string,
	Health: number,
	Stamina: number,

	-- Character References
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	HRP: BasePart,
	Animate: Instance,

	-- State Flags
	Sprinting: boolean,
	JumpSignalled: boolean,
	RollSignalled: boolean,
	IsRagdolled: boolean,
	AnimationControllerState: boolean,
	Legless: boolean,

	-- Equipment
	CurrentGun: Gun?,

	-- Data Tables
	LimbHealth: {},
	BodyParts: {},
	AnimationRefs: {},

	-- Utilities
	Janitor: any,

	-- Methods
	Ragdoll: (self: Human) -> (),
	UnRagdoll: (self: Human) -> (),
	ToggleRagdoll: (self: Human) -> (),
	IsAlive: (self: Human) -> boolean,
	Destroy: (self: Human) -> (),
	OnDeath: (self: Human) -> (),

	DisableLimb: (self: Human, limbName: string) -> (),
	ApplyImpulse: (self: Human, force: Vector3, position: Vector3?) -> (),
	ApplyImpulseOnLimb: (self: Human, limbName: string, force: Vector3) -> (),
}

export type HumanPlayer = Human & {
	Player: Player,
}

return nil
