local module = {}

local SignalModule = require(script.Parent.Utils.Signal)
local NpcAnimationTypes = require(script.Parent.NpcAnimationTypes)

export type clientNpcRecordType = {
	janitor: any,
	npcId: number,
	timeline: { any },
	eventline: { any },
	instance: Model,
	isDead: boolean,
	bloodEmitterRefs: { [number]: (ParticleEmitter | boolean)? },
	humanoid: Humanoid?,
	bodyParts: { [number]: BasePart? },
	rightArmConstraint: BasePart?,
	recoilSpring: any,
	isRecoiling: boolean,
	recoilAngle: number,
	disabledLimbs: { [number]: boolean },
	hz: number,
	invHz: number,
	placed: boolean,
	cframe: CFrame,
	animations: { [number]: NpcAnimationTypes.AnimEntry },
	playingAnimations: { [number]: NpcAnimationTypes.AnimEntry? },
	animator: Animator?,
	loaded: boolean,
	onCustomEvent: SignalModule.Signal,
}

return module
