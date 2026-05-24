export type Gun = {
	Tool: Tool?,
	MaxAmmo: number,
	Name: string,
	CurrentAmmo: number,
	AmmoReserve: number,
	ShotDelay: number,
	ShootPoint: Attachment?,
	PlayerRef: Player?,
	CanShoot: boolean,
	ShootGun: () -> (),
	Reload: (self: Gun) -> (),
	MuzzleFlash: Attachment?,
	HumanClassRef: Human?,
}

export type Throwable = {
	Name: string,
	Tool: Tool?,
	Owner: Human,
	CurrentAmmo: number,
	DetonationTime: number,
	ThrowVelocity: number,

	Throw: (self: Throwable, cameraLookVector: Vector3) -> (),
	UpdateAmmo: (self: Throwable, amount: number) -> boolean,
}
export type Inventory = {
	-- Owner
	Owner: Human,

	-- Items
	Items: { [string]: number },
	MaxSlots: number,
	OccupiedSlots: number,

	-- Weapons
	StoredWeapons: {
		Gun: Gun?,
		Throwable: Throwable?,
	},
	EquippedWeapons: {
		Gun: boolean,
		Throwable: boolean,
	},

	-- Methods
	IsEquippingWeapon: (self: Inventory, weaponType: string) -> boolean,
	RemoveWeapon: (self: Inventory, weaponType: string) -> boolean,
	CanEquip: (self: Inventory) -> boolean,
	SwapWeapon: (self: Inventory, newWeaponName: string, weaponType: string) -> boolean,
	EquipWeapon: (self: Inventory, weaponType: string) -> boolean?,
	AddWeaponToInventory: (self: Inventory, name: string, quantity: number?) -> boolean,
	GetAvailableSlotCount: (self: Inventory) -> number,
	GetMaxSlotCount: (self: Inventory) -> number,
	GetOccupiedSlotCount: (self: Inventory) -> number,
	GetGun: (self: Inventory) -> Gun?,
	GetThrowable: (self: Inventory) -> Throwable?,
	IsFull: (self: Inventory) -> boolean,
}
export type AI = {
	-- Identity
	Type: string?,
	Owner: Human,

	-- State
	StateMachine: any,
	EnemyList: { [string]: boolean },
	AttackStateName: string,

	-- Pathfinding
	SeekTurnDelay: number,

	MinAttackDistance: number,
	MaxAttackDistance: number,

	-- Methods
	new: (owner: Human) -> AI,
	Initialize: (self: AI) -> (),
	StateChangeReset: (self: AI) -> (),
	IsTargetInView: (self: AI, originPos: Vector3, target: BasePart | Model, useFOV: boolean) -> boolean,
	TweenLookAround: (self: AI, hrp: BasePart, remaining: number) -> boolean | Model,
	LookAround: (self: AI, seekDir: Vector3?) -> boolean | Model,
	TargetIsEnemy: (self: AI, target: Instance) -> boolean,
	GetThrowAngle: (self: AI, origin: Vector3, target: Vector3, velocity: number) -> (number?, number?),
	ThrowThrowable: (self: AI, targetPos: Vector3) -> boolean,
	CheckSurroundingsForEnemy: (self: AI) -> Model | boolean,
	Patrol: (self: AI, patrolData: { Vector3 }) -> (),
	CheckLineOfSight: (self: AI) -> { BasePart }?,
	PathFindTo: (self: AI, targetPos: Vector3) -> (),
}

export type Human = {
	-- Identity
	HumanType: string,
	Dead: boolean,
	Legless: boolean,
	IsRagdolled: boolean,
	AnimationControllerState: boolean,
	Invincible: boolean,
	Inventory: Inventory,

	-- References
	Character: Model,
	Humanoid: Humanoid,
	HRP: BasePart,
	RootPart: BasePart,
	Animator: Animator?,
	Player: Player?,

	-- Stats
	Health: number,
	Stamina: number,
	Sprinting: boolean,
	JumpSignalled: boolean,
	RollSignalled: boolean,

	-- Limbs
	LimbHealth: { [string]: number },
	BodyParts: { [string]: BasePart | boolean },
	DisabledBodyParts: { [string]: boolean },

	-- Janitor
	Janitor: any,

	InCombat: boolean,

	-- Methods
	new: (humanoid: Humanoid?) -> Human,
	GetHealthPercentage: (self: Human) -> number,
	SetupPhysicsSettings: (self: Human) -> (),
	ApplyRollForce: (self: Human) -> (),
	ApplyKickForce: (self: Human) -> (),
	AssignBodyParts: (self: Human, tagName: string) -> (),
	SimulateDefaultLimbs: (self: Human) -> (),
	OnHumanoidStateChange: (self: Human) -> (),
	OnHit: (self: Human, damage: number, damageMultiplier: number, limbName: string, shooter: Player | Model) -> (),
	Die: (self: Human, shooter: Player?) -> (),
	FixCrawlADS: (self: Human) -> (),
	SetCrawlState: (self: Human) -> (),
	DisableLimb: (self: Human, limbName: string) -> (),
	DestroyLimb: (self: Human, limbName: string) -> (),
	OnDeath: (self: Human) -> (),
	OnSetInvincibleFor: (self: Human, duration: number, excludeFromCooldown: boolean) -> (),
	Ragdoll: (self: Human, ragdollTime: number) -> (),
	ApplyImpulse: (self: Human, force: Vector3, position: Vector3?) -> (),
	Destroy: (self: Human) -> (),
	DropMoney: (self: Human) -> (),
	SetInvincible: (self: Human, isInvincible: boolean, excludeFromCooldown: boolean?) -> (),
}

export type HumanPlayer = Human & {
	HumanType: "Player",
	Player: Player,
	AdjustGrayscale: (self: HumanPlayer) -> (),
}

export type HumanNPC = Human & {
	HumanType: "NPC",
	AI: AI,
}

export type Destroyable = {
	ModelRef: Instance?,
	Name: string,
	Health: number,
	Type: string,
	HumanEffect: string,

	Damage: (self: Destroyable, damageAmount: number, shooter: Player?) -> (),
	Destroy: (self: Destroyable) -> (),
}

export type DamageData = {
	TargetHuman: Human,
	Damage: number,
	Shooter: Player?,
}
export type InflictingDamage = DamageData & {
	Type: "Inflict",
	SpreadParticleName: string?,
	SpreadDuration: number?,
	LimbHit: BasePart,
}

export type GunShotDamage = DamageData & {
	Type: "Shot",
	RaycastResult: RaycastResult,
	ShotPosition: Vector3?,
}

return nil
