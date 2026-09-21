--[[
	================================================================================
	 ASH CONSTRUCTOR / Similar to snow
	================================================================================
	This constructor creates a ash fall effect.
]]

local module = {}

module.Settings = {
	Direction			 = Vector3.new(0, -1, 0),

	Speed				 = 0.75,
	Scale				 = 1.4,
	
	Intensity			 = 80,
	FadeInTime			 = 0.2,
	FadeOutTime			 = 0.5,
	BeamDuration		 = 2,
	WindInfluence		 = 1,
	Randomness			 = 8,

	Color				 = Color3.fromRGB(255,168,55),
	Transparency		 = 0,
	Brightness			 = 1.4,
	LightEmission		 = 0,
	LightInfluence		 = 0,

	MistParticles		 = true,
	SplashParticles		 = true,
	BeamEffect			 = true,
	SnowLayers			 = false,

	SplashThreshold		 = 0.6,
	ExtraMistParticles	 = 2,

	SoundId				 = "",
	BeamTextureId		 = "rbxassetid://89465118585474",
	MistTextureId		 = "rbxassetid://113251424622160",
	SplashTextureId		 = "rbxassetid://113251424622160",
	
	SphereCast			 = true,
	SphereCastRadius	 = 6,
	RaycastRadius		 = 80,
	RaycastHeight		 = 300,
	VisualHeight		 = 80,
	
	SoundVolume			 = 0.1,
	DynamicSoundRadius	 = 40,
}

module.Constructor = function()
	-- Top attachment (rain origin) with Mist emitter
	local TopAttachment = Instance.new("Attachment")
	TopAttachment.Name = "TopSnowParticle"

	local Mist = Instance.new("ParticleEmitter")
	Mist.Name = "Mist"
	Mist.Size = NumberSequence.new(10)
	Mist.Texture = module.Settings.MistTextureId
	Mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.4,0.2),
		NumberSequenceKeypoint.new(0.6,0.2),
		NumberSequenceKeypoint.new(1,1),
	})
	Mist.Brightness = 1
	Mist.LightEmission = 0
	Mist.LightInfluence = 0
	Mist.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	Mist.Enabled = false
	Mist.LockedToPart = false
	Mist.EmissionDirection = Enum.NormalId.Front
	Mist.Lifetime = NumberRange.new(3)
	Mist.Rate = 0
	Mist.Rotation = NumberRange.new(0, 360)
	Mist.RotSpeed = NumberRange.new(-5, 5)
	Mist.Speed = NumberRange.new(15)
	Mist.SpreadAngle = Vector2.new(5, 5)
	Mist.Drag = 0
	Mist.Parent = TopAttachment

	-- Bottom attachment (impact point) with Beam + Splash emitter
	local BottomAttachment = Instance.new("Attachment")
	BottomAttachment.Name = "BottomSnowParticle"

	local Beam = Instance.new("Beam")
	Beam.Name = "Beam"
	Beam.Enabled = false
	Beam.Texture = module.Settings.BeamTextureId
	Beam.Attachment0 = TopAttachment
	Beam.Attachment1 = BottomAttachment
	Beam.Width0 = 8
	Beam.Width1 = 8
	Beam.FaceCamera = true
	Beam.Segments = 2
	Beam.Brightness = 1
	Beam.LightInfluence = 0
	Beam.LightEmission = 0
	Beam.TextureLength = 2
	Beam.TextureSpeed = 0.2
	Beam.Transparency = NumberSequence.new(0)
	Beam.Parent = BottomAttachment

	local BottomSplash = Instance.new("ParticleEmitter")
	BottomSplash.Name = "Splash"
	BottomSplash.Texture = module.Settings.SplashTextureId
	BottomSplash.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
	BottomSplash.FlipbookMode = Enum.ParticleFlipbookMode.Random
	BottomSplash.FlipbookStartRandom = true
	BottomSplash.FlipbookBlendFrames = false
	BottomSplash.FlipbookFramerate = NumberRange.new(0)
	BottomSplash.Enabled = false
	BottomSplash.LockedToPart = false
	BottomSplash.LightEmission = 0
	BottomSplash.LightInfluence = 0
	BottomSplash.ZOffset = 0.1
	BottomSplash.Brightness = 1
	BottomSplash.Rate = 0.3
	BottomSplash.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	BottomSplash.Drag = 0
	BottomSplash.RotSpeed = NumberRange.new(0)
	BottomSplash.Speed = NumberRange.new(-0.01)
	BottomSplash.Rotation = NumberRange.new(0, 360)
	BottomSplash.Lifetime = NumberRange.new(4)
	BottomSplash.SpreadAngle = Vector2.new(0, 0)
	BottomSplash.EmissionDirection = Enum.NormalId.Top
	BottomSplash.Size = NumberSequence.new(3)
	BottomSplash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.2,0),
		NumberSequenceKeypoint.new(0.8,0),
		NumberSequenceKeypoint.new(1,1),
	})
	BottomSplash.Parent = BottomAttachment

	-- Standalone splash attachment (additional randomized ground splash particles for realism)
	local SplashAttachment = Instance.new("Attachment")
	SplashAttachment.Name = "SplashAttachment"

	local StandaloneSplash = BottomSplash:Clone()
	StandaloneSplash.Parent = SplashAttachment

	return TopAttachment, BottomAttachment, SplashAttachment
end

return module
