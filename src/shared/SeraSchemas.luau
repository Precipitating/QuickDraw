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
}
