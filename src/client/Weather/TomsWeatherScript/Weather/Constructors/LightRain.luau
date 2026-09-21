--[[
	================================================================================
	 LIGHT RAIN CONSTRUCTOR
	================================================================================
	This constructor creates rain effect visualizing each individual droplet.
]]

local module = {}

module.Settings = {
	Direction			 = Vector3.new(0, -1, 0),

	Speed				 = 1,
	Scale				 = 1,
	
	SplashIntensity		 = 0,
	Intensity			 = 200,
	FadeInTime			 = 0,
	FadeOutTime			 = 0,
	BeamDuration		 = 0.5,
	WindInfluence		 = 1,
	Randomness			 = 8,

	Color				 = Color3.new(1,1,1),
	Transparency		 = 0,
	Brightness			 = 1,
	LightEmission		 = 0.3,
	LightInfluence		 = 0.7,

	MistParticles		 = true,
	SplashParticles		 = true,
	BeamEffect			 = true,
	SnowLayers			 = false,

	SplashThreshold		 = 0,
	ExtraMistParticles	 = 0,

	SoundId				 = "rbxassetid://1516791621",
	BeamTextureId		 = "rbxassetid://125617796867037",
	MistTextureId		 = "rbxassetid://124053983267495",
	SplashTextureId		 = "rbxassetid://6742725368",
	
	SphereCast			 = false,
	RaycastRadius		 = 80,
	RaycastHeight		 = 300,
	VisualHeight		 = 80,
	
	SoundVolume			 = 0.1,
	DynamicSoundRadius	 = 55,
}

module.Constructor = function()
	-- Top attachment (rain origin) with Mist emitter
	local TopAttachment = Instance.new("Attachment")
	TopAttachment.Name = "TopRainParticle"

	local Mist = Instance.new("ParticleEmitter")
	Mist.Name = "Mist"
	Mist.Texture = module.Settings.MistTextureId
	Mist.Enabled = false
	Mist.LockedToPart = false
	Mist.LightEmission = 0
	Mist.LightInfluence = 1
	Mist.Size = NumberSequence.new(20)
	Mist.Rate = 0
	Mist.Drag = 0
	Mist.SpreadAngle = Vector2.new(0, 0)
	Mist.Lifetime = NumberRange.new(0.8)
	Mist.EmissionDirection = Enum.NormalId.Front
	Mist.Rotation = NumberRange.new(0, 360)
	Mist.RotSpeed = NumberRange.new(-80, 80)
	Mist.Speed = NumberRange.new(80,100)
	Mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(0.08,0.99),
		NumberSequenceKeypoint.new(0.15,0.98),
		NumberSequenceKeypoint.new(0.92,0.99),
		NumberSequenceKeypoint.new(1,1),
	})
	Mist.Parent = TopAttachment

	-- Bottom attachment (impact point) with Beam + Splash emitter
	local BottomAttachment = Instance.new("Attachment")
	BottomAttachment.Name = "BottomRainParticle"

	local Beam = Instance.new("Beam")
	Beam.Name = "Beam"
	Beam.Texture = module.Settings.BeamTextureId
	Beam.Enabled = true
	Beam.FaceCamera = true
	Beam.Segments = 2
	Beam.LightInfluence = 0.5
	Beam.LightEmission = 0
	Beam.TextureLength = 0.75
	Beam.TextureSpeed = 2
	Beam.Width0 = 35
	Beam.Width1 = 35
	Beam.Transparency = NumberSequence.new(0.5)
	Beam.Parent = BottomAttachment

	local BottomSplash = Instance.new("ParticleEmitter")
	BottomSplash.Name = "Splash"
	BottomSplash.Texture = module.Settings.SplashTextureId
	BottomSplash.Enabled = false
	BottomSplash.LockedToPart = false
	BottomSplash.LightEmission = -0.3
	BottomSplash.LightInfluence = 0.9
	BottomSplash.ZOffset = 0.1
	BottomSplash.Rate = 0
	BottomSplash.Drag = 10
	BottomSplash.RotSpeed = NumberRange.new(0)
	BottomSplash.Speed = NumberRange.new(0)
	BottomSplash.Rotation = NumberRange.new(0, 360)
	BottomSplash.Lifetime = NumberRange.new(0.6)
	BottomSplash.SpreadAngle = Vector2.new(0)
	BottomSplash.EmissionDirection = Enum.NormalId.Front
	BottomSplash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(0.5,0),
		NumberSequenceKeypoint.new(0.775,0.85),
		NumberSequenceKeypoint.new(1,1),
	})
	BottomSplash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(0.6,0),
		NumberSequenceKeypoint.new(1,1.6),
	})
	BottomSplash.Parent = BottomAttachment

	-- Standalone splash attachment (additional randomized ground splash particles for realism)
	local SplashAttachment = Instance.new("Attachment")
	SplashAttachment.Name = "SplashAttachment"

	local StandaloneSplash = BottomSplash:Clone()
	StandaloneSplash.Drag = 0
	StandaloneSplash.Speed = NumberRange.new(0)
	StandaloneSplash.SpreadAngle = Vector2.zero
	StandaloneSplash.Lifetime = NumberRange.new(0.2, 0.3)
	StandaloneSplash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,0),
		NumberSequenceKeypoint.new(0.6, 0.85),
		NumberSequenceKeypoint.new(1,1),
	})
	StandaloneSplash.Size = NumberSequence.new(0, 1.6)
	StandaloneSplash.Parent = SplashAttachment

	return TopAttachment, BottomAttachment, SplashAttachment
end

return module
