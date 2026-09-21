--[[
	================================================================================
	 SANDSTORM CONSTRUCTOR / Based on Ash
	================================================================================
	Wind-driven dust. Direction is mostly horizontal, so the top attachment sits
	upwind of the impact point and the streaks run along the wind.
]]

local module = {}

module.Settings = {
	Direction = Vector3.new(1, -0.2, 0.3),

	Speed = 1.5,
	Scale = 1.2,

	Intensity = 120,
	SplashIntensity = 40,
	FadeInTime = 0.15,
	FadeOutTime = 0.4,
	BeamDuration = 0.7,
	WindInfluence = 1,
	Randomness = 5,

	Color = Color3.fromRGB(214, 178, 120),
	Transparency = 0.1,
	Brightness = 1.2,
	LightEmission = 0,
	LightInfluence = 1,

	MistParticles = true,
	SplashParticles = true,
	BeamEffect = true,
	SnowLayers = false,

	SplashThreshold = 0.1,
	ExtraMistParticles = 2,

	SoundId = "rbxassetid://113371346641768",
	BeamTextureId = "rbxassetid://9481817416",
	MistTextureId = "rbxassetid://9481817416",
	SplashTextureId = "rbxassetid://15793916269",

	SphereCast = false,
	SphereCastRadius = 4,
	RaycastRadius = 70,
	RaycastHeight = 120,
	VisualHeight = 90,

	SoundVolume = 0.4,
	DynamicSoundRadius = 40,
}

module.Constructor = function()
	-- Top attachment (upwind end of the streak) with Mist emitter
	local TopAttachment = Instance.new("Attachment")
	TopAttachment.Name = "TopSandParticle"

	local Mist = Instance.new("ParticleEmitter")
	Mist.Name = "Mist"
	Mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 6),
		NumberSequenceKeypoint.new(1, 14),
	})
	Mist.Texture = module.Settings.MistTextureId
	Mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	Mist.Brightness = 1
	Mist.LightEmission = 0
	Mist.LightInfluence = 1
	Mist.Orientation = Enum.ParticleOrientation.FacingCamera
	Mist.Enabled = false
	Mist.LockedToPart = false
	Mist.EmissionDirection = Enum.NormalId.Front
	Mist.Lifetime = NumberRange.new(2, 2.5)
	Mist.Rate = 0
	Mist.Rotation = NumberRange.new(0, 360)
	Mist.RotSpeed = NumberRange.new(-20, 20)
	Mist.Speed = NumberRange.new(35, 45)
	Mist.SpreadAngle = Vector2.new(6, 6)
	Mist.Drag = 0
	Mist.Parent = TopAttachment

	-- Bottom attachment (impact point) with Beam + Splash emitter
	local BottomAttachment = Instance.new("Attachment")
	BottomAttachment.Name = "BottomSandParticle"

	local Beam = Instance.new("Beam")
	Beam.Name = "Beam"
	Beam.Enabled = false
	Beam.Texture = module.Settings.BeamTextureId
	Beam.Attachment0 = TopAttachment
	Beam.Attachment1 = BottomAttachment
	Beam.Width0 = 4
	Beam.Width1 = 4
	Beam.FaceCamera = true
	Beam.Segments = 2
	Beam.Brightness = 1
	Beam.LightInfluence = 1
	Beam.LightEmission = 0
	Beam.TextureLength = 12
	Beam.TextureSpeed = 6 -- positive scrolls toward Attachment1 (downwind)
	Beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
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
	BottomSplash.LightInfluence = 1
	BottomSplash.ZOffset = 0.1
	BottomSplash.Brightness = 1
	BottomSplash.Rate = 0 -- 0 = one puff per impact (module calls Emit(1))
	BottomSplash.Orientation = Enum.ParticleOrientation.FacingCamera
	BottomSplash.Drag = 3
	BottomSplash.RotSpeed = NumberRange.new(-30, 30)
	BottomSplash.Speed = NumberRange.new(4, 10)
	BottomSplash.Rotation = NumberRange.new(0, 360)
	BottomSplash.Lifetime = NumberRange.new(1, 1.6)
	BottomSplash.SpreadAngle = Vector2.new(50, 50)
	BottomSplash.EmissionDirection = Enum.NormalId.Top
	BottomSplash.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 10),
	})
	BottomSplash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	BottomSplash.Parent = BottomAttachment

	-- Standalone splash attachment (extra ground puffs between streaks)
	local SplashAttachment = Instance.new("Attachment")
	SplashAttachment.Name = "SplashAttachment"

	local StandaloneSplash = BottomSplash:Clone()
	StandaloneSplash.Parent = SplashAttachment

	return TopAttachment, BottomAttachment, SplashAttachment
end

return module
