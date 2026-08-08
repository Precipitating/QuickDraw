local NpcState = {
	Idle = 0,
	Running = 1,
	Jumping = 2,
	Falling = 3,
	CrashLand = 4,
	Dying = 5,
	Ragdolled = 6,
} :: { [string]: number }

export type NpcState = number

return NpcState
