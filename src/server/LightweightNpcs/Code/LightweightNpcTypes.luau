local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local Signal = require(ReplicatedStorage.Packages.Signal)
local SignalModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.Signal)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local NpcAnimationTypes = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcAnimationTypes)
type NpcState = NpcStateModule.NpcState

export type npcRecordInternal = {
	timeOfNextReplicate: number,
	forceReplicate: boolean,
	forceThink: boolean,
	timeOfNextThink: number,
	timeOfLastThink: number,

	timeOfNextCullingCheck: number,

	deleteFlag: boolean, --Setting this will clean the npc up before next frame

	pendingAnimationChanges: { [number]: number }, -- We hold onto these based on animation replication rates
	playerReplicationVisible: { [Player]: boolean }, -- Is currently visible to player (nil means not evaluated yet)
	playerVisibleFlag: { [Player]: boolean }, --Desire to be visible to a given player (nil means visible)
}

export type npcRecordConfiguration = {
	maximumStepHeight: number,
	maximumSlopeAngle: number,
	templateInstance: Instance,
	replicationHzRate: number,
	thinkHzRate: number,
	motionSize: Vector3, -- Used for motion, doesn't technically need to be same size as the hitbox
	groundTolerance: number, -- Todo: remove this, should be epsil
	animations: NpcAnimationTypes.FinalAnimTable, -- Table of animations for the client to load in
	walkSpeed: number, -- Same as roblox, 16 etc
	walkAccel: number, -- Roblox uses a high value here like 20, I prefer 3 or 4
	turnSpeed: number, -- Radians per second
	gravity: Vector3,
	jumpPower: number,
}

export type npcRecordType = {
	npcId: number,

	instance: Model, --Roblox model instance thats displayed on all clients
	serverRig: Model, --The hitbox that exists on the server
	janitor: any,

	internal: npcRecordInternal, --timers etc
	configuration: npcRecordConfiguration, --mostly constant

	--Primary state
	npcState: NpcState, --Idle, falling, etc
	hitPoints: number,
	humanType: number,
	invincible: boolean,
	playingAnimations: { [number]: NpcAnimationTypes.AnimEntry? }, --Four channels I guess?
	animator: Animator?,
	poses: { [string]: AnimationTrack },
	--Motion
	position: Vector3,
	angle: number, --Actual heading
	targetAngle: number, --target heading
	velocity: Vector3, --units per second
	activeMoveThread: any?,
	isOnGround: boolean, --bool
	motionVector: Vector3, --setting this controls where the npc will try and move to
	jump: boolean, --A jump is requested

	--
	bodyParts: { [number]: { Part: MeshPart, HP: number, State: string } },
	hrp: BasePart,
	legless: boolean,
	killedBy: Player? | Model?,
	npcType: string?,
	enemies: { [string]: boolean },
	faction: string?,
	currentEquipped: any?,
	storedWeapon: any?,
	storedThrowable: any?,
	defaultStateData: any?,

	-- NPC AI conditions

	ai: {
		worldState: any,
		perception: any,
		navigation: any,
		pathfinder: any,
		jumpRequested: boolean?,
		jumpFinishedSignal: any,
		moveFinishedSignal: any,
		currentGoal: any?,
		currentPlan: any?,
		currentNavigationData: {}?,
		defaultState: string?,
	},

	--Methods
	PlayAnimation: (
		self: npcRecordType,
		animName: string,
		forceRestart: boolean,
		channel: number,
		speedMultiplier: number
	) -> (),
	StopAnimationChannel: (self: npcRecordType, channel: number) -> (),
	AddClientEvent: (self: npcRecordType, event: any) -> (),
	SetPlayerVisibleFlag: (self: npcRecordType, player: Player, visible: boolean) -> (),
	GetPlayerVisibleFlag: (self: npcRecordType, player: Player) -> boolean,
	ForceReplicate: (self: npcRecordType) -> (), --Forces a pos/angle update asap on this entity. Do this if you're using low replication rates and your NPC does something sudden, like jumping

	Move: (self: npcRecordType, motionVector: Vector3) -> (),
	Jump: (self: npcRecordType) -> (),

	--Callbacks
	onThink: SignalModule.Signal,
	onFellOffMap: SignalModule.Signal,
	onDeath: SignalModule.Signal, --Can still be a corpse after this for a while
	onCleanup: SignalModule.Signal, --Removed from universe for good
	onBumpIntoWall: SignalModule.Signal,
	onDisableLimb: SignalModule.Signal,
	onDismemberLimb: SignalModule.Signal,
	onRagdoll: SignalModule.Signal,
	onPoseChange: SignalModule.Signal,
	onHit: SignalModule.Signal,
	onLimbHit: SignalModule.Signal,
	onCrashland: SignalModule.Signal,
	onCullCheck: SignalModule.Signal,

	--Put your random stuff in here :)
	data: any,
}

return module
