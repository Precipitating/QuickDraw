local module = {}

local SignalModule = require(script.Parent.Utils.Signal)
local NpcAnimationTypes = require(script.Parent.NpcAnimationTypes)

export type clientNpcRecordType = {
	npcId: number,
	timeline: { any },
	eventline: { any },
	instance: Model,
	isDead: boolean,
	bloodEmitterRefs: { [number]: (ParticleEmitter | boolean)? },
	humanoid: Humanoid?,
	bodyParts: { [number]: (BasePart | boolean)? },
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
