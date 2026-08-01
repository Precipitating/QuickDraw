local Sera = require(script.Parent.Sera)
return {
	TrainPositionSchema = Sera.Schema({
		CurrentSpeed = Sera.Float32,
		Distance = Sera.Float32,
	}),

	Play3DOneShotSchema = Sera.Schema({
		SoundName = Sera.String8,
		Position = Sera.Vector3,
		Volume = Sera.Float32, -- optional
		Pitch = Sera.Float32, -- optional
		MaxDistance = Sera.Float32, -- optional
	}),

	Play3DNPCVoicelineSchema = Sera.Schema({
		SoundName = Sera.String8,
		Volume = Sera.Float32, -- optional
		Pitch = Sera.Float32, -- optional
		MaxDistance = Sera.Float32, -- optional
	}),
	DisplayDestroySchema = Sera.Schema({
		DestroyableParticleName = Sera.String8,
		Position = Sera.Vector3,
	}),

	DisplaySpreadParticleSchema = Sera.Schema({
		DestroyableParticleName = Sera.String8,
		Duration = Sera.Int8,
	}),
	DisplayProjectileMarkSchema = Sera.Schema({
		Name = Sera.String8,
		Position = Sera.Vector3,
		Normal = Sera.Vector3,
	}),
	DisplayBloodHitSchema = Sera.Schema({
		Position = Sera.Vector3,
		Normal = Sera.Vector3,
	}),

	UpdateLimbGUIHPSchema = Sera.Schema({
		LimbName = Sera.String8,
		LimbHealthPercentage = Sera.Float32,
	}),

	ScreenEffectsSchema = Sera.Schema({
		EffectName = Sera.String8,
	}),

	NPCSchema = Sera.Schema({
		ID = Sera.Int8,
		CFrame = Sera.LossyCFrame,
		-- 1 = Bandit | 2 = Sheriff | 3 = Mercenary | 4 = Buffalo | 5 = Horse
		Faction = Sera.Uint8,
	}),
}
