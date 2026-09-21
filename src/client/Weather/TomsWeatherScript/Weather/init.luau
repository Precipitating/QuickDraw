--[[
	ULTIMATE WEATHER MODULE
	by tommc1337
	
	================================================================================
	 LICENSE
	================================================================================
	
	Copyright (c) 2026 tommc1337 [roblox.com/users/123456789] All rights reserved.
	Licensed under a custom license — no standalone redistribution.
	Full terms: see "LICENSE" file/object shipped alongside this module.
	
	================================================================================
	 EXAMPLE USAGE (from LocalScript)
	================================================================================

	local SoundGroup = Instance.new("SoundGroup")
	SoundGroup.Parent = game:GetService("SoundService")

	local module = require(PATH_TO_MODULE)
	module:SetWeather("Snow") -- Loads the snow template

	module:Start() --// optionally also module:Enable()
	task.wait(5)
	module:Stop()  --// optionally also module:Disable()

	================================================================================
	 WEATHER MODULE — API DOCUMENTATION
	================================================================================
	A client-side dynamic weather system (rain/snow/etc.) built on attachments,
	beams, and particle emitters. Handles raycasting against the world to place
	rain streaks and splashes, positional ambience sound, and live-tweakable
	settings.

	--------------------------------------------------------------------------
	PROPERTIES
	--------------------------------------------------------------------------
	Module.Settings            (table)          Live table of all current settings.
	                                             Do NOT mutate directly — use the
	                                             Set<Name>() functions below so
	                                             visuals/sound update accordingly.
	Module.Running             (boolean)        True while the weather loop is active.
	Module.SettingUpdated      (BindableEvent)  Fires as (settingName: string, value: any)
                                             	 whenever any Set<Name>() function runs.
    Module.StateUpdated		   (BindableEvent)  Fires as (running: boolean) whenever the
                                                 weather loop is started or stopped.
    Module.AttachmentCounter   (NumberValue)    Increments every time a new attachment
                                                 is created.

	--------------------------------------------------------------------------
	LIFECYCLE
	--------------------------------------------------------------------------
	Module:Start() / Module:Enable()
		Begins the weather simulation loop (rain generation, splash/Mist
		particles, ambience sound). Loads/creates attachment templates for the
		current Weather setting if not already loaded. No-op if already running.

	Module:Stop() / Module:Disable()
		Stops the weather loop. Active rain/sound fade out and clean up
		asynchronously; instances are pooled for reuse rather than destroyed.

	Module:Cleanup()
		Fully stops the weather system and destroys ALL instances it has ever
		created (templates, attachment pools, sounds) except the templates for
		the currently active Weather. Use when permanently done with the module
		(e.g. on script teardown). After calling this, attachment/sound state is
		reset to empty.

	--------------------------------------------------------------------------
	WEATHER / CORE SETTINGS
	--------------------------------------------------------------------------
	Module:SetWeather(weather: string)
		Switches to a different weather preset (must match a child ModuleScript
		under Constructors, e.g. "Rain"). Reloads attachment templates and
		re-applies weather-specific default settings. If already running, stops,
		cleans up, and restarts under the new weather. Invalid weather names emit
		a warning and fall back to "Rain".

	Module:SetDirection(direction: Vector3?)
		Sets the base fall direction of precipitation (combined with world wind
		via WindInfluence). Passing nil resets to the default (straight down).
		A zero-magnitude vector is rejected and reset to default.

	Module:SetWindInfluence(influence: number?)
		Scales how much workspace.GlobalWind affects the fall direction.
		Clamped to be non-negative.

	Module:SetSpeed(speed: number?)
		Global multiplier for particle/beam animation speed, lifetimes, and tick
		timing. Higher = faster-moving, shorter-lived beam streaks.

	Module:SetScale(scale: number?) / Module:SetSize(scale: number?)
		Multiplier for the visual size of beams, Mist, and splash particles.

	Module:SetIntensity(intensity: number?)
		Number of rain rays cast (and streaks spawned) per second. Triggers max attachment pool
		recalculation.
		
	Module:SetSplashIntensity(intensity: number?)
		Number of additional rain splashes per second. Triggers max splash attachment pool
		recalculation.

	Module:SetRandomness(randomness: number?)
		Sets the random angle rotation to apply to the direction. Must be non-negative.

	Module:SetVisualHeight(height: number?)
		Length (studs) of each individual rain streak/beam from its top to
		bottom attachment. The function also updates the beams and particles
		to match.

	Module:SetBeamDuration(duration: number?)
		How long (seconds) a rain beam stays fully
		visible between its fade-in and fade-out. Triggers attachment pool
		recalculation. Must be non-negative.

	Module:SetFadeInTime(duration: number?)
		Seconds (before Speed scaling) for a rain beam to fade in from
		invisible. Triggers max attachment pool recalculation. Must be non-negative.

	Module:SetFadeOutTime(duration: number?)
		Seconds (before Speed scaling) for a rain beam to fade out before being
		recycled. Triggers max attachment pool recalculation. Must be non-negative.

	--------------------------------------------------------------------------
	APPEARANCE
	--------------------------------------------------------------------------
	Module:SetColor(color: Color3?)
		Tint applied to all beam, Mist, and splash particles.

	Module:SetTransparency(opacity: number?)
		Global transparency multiplier (0 = fully opaque per template, 1 = fully
		invisible) applied on top of each particle/beam's own transparency
		sequence.
		
	Module:SetBrightness(value: number?)
		Controls how bright the particles/beams texture is.

	Module:SetLightInfluence(luminance: number?)
		Controls how much the particles/beams are influenced by light.
	
	Module:SetLightEmission(emission: number?)
		Controls how much the particles/beams blend with the colors behind it.

	Module:SetMistParticles(enabled: boolean?)
		Toggles whether Mist/mist particles are emitted at rain impact points.

	Module:SetSplashParticles(enabled: boolean?)
		Toggles splash particles.

	Module:SetBeamEffect(enabled: boolean?)
		Toggles beam streaks on/off.

	Module:SetSplashThreshold(threshold: number?)
		Minimum surface normal Y-value (0–1) required for a splash to spawn at
		an impact point (prevents splashes on steep/vertical surfaces). Clamped
		to [0, 1].

	Module:SetSnowLayers(enabled: boolean?)
		Toggles whether a snow-covered clones are generated on
		up-facing surfaces that rain/snow rays hit.
		Clears layers on Module:Cleanup() or if disabled.
		
	Module:SetIgnoreSnowTag(tag: string?)
		BaseParts with this tag will not generate snow layers.

	Module:SetPartLockedSplash(enabled: boolean?)
		Toggles whether splash attachments are parented to instances they hit.
		This causes them to move with the surface, but can be disabled to
		improve performance. When enabled, a ton of attachments will be created
		and is not recommended for low-end devices. If disabled, previous
		attachments will be destroyed and replaced with new ones in the 
		ignorance folder.

	Module:SetExtraMistParticles(count: number?)
		Number of additional trailing Mist attachments spawned per rain streak
		(creates a denser falling-particle trail).

	--------------------------------------------------------------------------
	TEXTURES
	--------------------------------------------------------------------------
	Module:SetBeamTextureId(id: string?)
		Asset ID used for the rain streak Beam texture.

	Module:SetMistTextureId(id: string?)
		Asset ID used for the Mist/mist ParticleEmitter texture.

	Module:SetSplashTextureId(id: string?)
		Asset ID used for the splash ParticleEmitter texture.

	--------------------------------------------------------------------------
	SOUND
	--------------------------------------------------------------------------
	Module:SetSoundId(id: string?)
		Asset ID of the looping ambience sound. Restarts playback if the
		weather loop is currently running.

	Module:SetSoundVolume(volume: number?)
		Base volume multiplier for the ambience sound. Must be non-negative.

	Module:SetSoundGroup(group: Instance?)
		Assigns the ambience Sound's SoundGroup. Must be a SoundGroup instance.

	Module:SetSoundParent(parent: Instance?)
		Instance the ambience Sound object should be parented to (defaults to
		SoundService if not set).

	Module:SetDynamicSound(enabled: boolean?)
		Toggles raycast dynamic volumetric sound (sound gets louder/
		quieter based on whether the camera is under cover). When disabled,
		a static volume is applied instead.

	Module:SetDynamicSoundRadius(radius: number?)
		RaycastRadius (studs) around the camera used to sample occlusion for
		dynamic sound calculations. Must be non-negative; a radius of 0 forces
		static sound behavior.

	Module:SetSoundGrid(template: string?)
		Determines which sound grid to use, templates in SoundGrids
	
	Module:SetVisualizeSoundGrid(enabled: boolean?)
		Toggles debug visualization for the sound raycast grid.

	--------------------------------------------------------------------------
	RAYCASTING
	--------------------------------------------------------------------------
	Module:SetRaycastRadius(radius: number?)
		Horizontal radius (studs) relative to the camera within which rain ray
		origins are randomly scattered.

	Module:SetRaycastHeight(height: number?)
		How far away from the camera from which rain rays are cast downward, and
		roughly how far they travel before being considered a miss.
		
	Module:SetRaycastParams(instances: {Instance}?)
		List of extra Instances to exclude from all rain/sound raycasts (in
		addition to the module's own internal ignore folder, camera, and local
		character).

	Module:SetIgnorePartsAboveTransparency(transparency: number?)
		Parts with transparency >= this value will be ignored by the raycast.
		If set to above 1 (eg. 2), no parts will be ignored based on
		transparency. 
		
	Module:SetIgnorePartsWithTag(tag: string?)
		Parts with this tag will be ignored by the raycast. If the part tag
		gets removed, the part will continue to be ignored by the raycast.
	
]]

local Module = {}

--// Services
local Debris     		= game:GetService("Debris")
local RunService  		= game:GetService("RunService")
local SoundService		= game:GetService("SoundService")
local TweenService		= game:GetService("TweenService")
local Players     		= game:GetService("Players")
local Terrain			= workspace:WaitForChild("Terrain")
local CollectionService = game:GetService("CollectionService")
local ContentProvider	= game:GetService("ContentProvider")

--// Stored Types (perf)
local CFrame_        = CFrame.new
local CFrameAngles_  = CFrame.Angles
local Vector3_       = Vector3.new
local TaskWait_      = task.wait
local TaskSpawn_	 = task.spawn
local TaskDelay_	 = task.delay
local TableInsert_   = table.insert
local Instance_      = Instance.new
local MathAbs_		 = math.abs
local MathRandom_    = math.random
local MathFloor_	 = math.floor
local MathRound_     = math.round
local MathRad_       = math.rad
local pi_			 = math.pi
local cos_			 = math.cos
local sin_			 = math.sin

--// ===================== DEFAULTS =====================

local DEFAULT_SETTINGS = {
	Weather						 = "Rain",

	Direction					 = Vector3.new(0, -1, 0),
	WindInfluence				 = 1,

	Speed						 = 1,
	Scale						 = 1,
	
	IgnorePartsWithTag			 = "IGNORE_WEATHER",
	IgnorePartsAboveTransparency = 0.95,
	RaycastRadius				 = 80,
	FadeInTime					 = 0.2,
	FadeOutTime					 = 0.5,
	BeamDuration				 = 2,
	Randomness					 = 8,
	
	Intensity					 = 120,
	SplashIntensity				 = 120,
	
	PartLockedSplash			 = false,

	Color						 = Color3.new(1,1,1),
	Transparency				 = 0,
	Brightness					 = 1,
	LightEmission				 = 0,
	LightInfluence				 = 1,

	MistParticles				 = true,
	SplashParticles				 = true,
	BeamEffect					 = true,
	
	SnowLayers					 = false,
	IgnoreSnowTag				 = "NoSnow",

	SplashThreshold				 = 0.5,
	ExtraMistParticles			 = 2,

	SoundId						 = "rbxassetid://9064263922",
	BeamTextureId				 = "rbxassetid://112462928223573",
	MistTextureId				 = "rbxassetid://124053983267495",
	SplashTextureId				 = "rbxassetid://6742725368",
	
	SphereCast					 = true,
	SphereCastRadius			 = 8,
	RaycastHeight				 = 300,
	VisualHeight				 = 80,
	
	DynamicSound				 = true,
	DynamicSoundRadius			 = 50,
	SoundVolume					 = 0.2,
	VisualizeSoundGrid			 = false,
	SoundGrid					 = "Custom-32",
	SoundGroup					 = nil,
	SoundParent					 = nil,

	ExcludeInstances			 = {},
}

--// Live Module.Settings (mutated only through Set<Name> functions)
Module.Settings = {}
for k, v in DEFAULT_SETTINGS do
	Module.Settings[k] = v
end

--// State
local RunToken = 0
Module.Running = false

--// Events
Module.SettingUpdated = Instance.new("BindableEvent")
Module.StateUpdated = Instance.new("BindableEvent")

--// Attachment Counter
Module.AttachmentCounter = Instance.new("NumberValue")

--// ===================== CLEANUP OLD INSTANCES =====================
local INSTANCE_TAG = "__WEATHER_INSTANCE" -- Do not change this unless you know what you are doing.
local PreExistingInstances = CollectionService:GetTagged(INSTANCE_TAG)
for _,Inst in PreExistingInstances do
	Inst:Destroy()
end

--// ===================== INSTANCE CONTAINER =====================
local TAG = "__TOMMCS_WEATHER_IGNORE_FOLDER"
local SoundGrids = require(script:WaitForChild("SoundGrids"))
local Constructors = script:WaitForChild("Constructors")
local IgnoreFolder = CollectionService:GetTagged(TAG)[1] or Instance_("Folder")
IgnoreFolder:AddTag(TAG)
IgnoreFolder.Name = "RainIgnorance"

local function UpdateIgnoranceFolder()
	if not CollectionService:GetTagged(TAG)[1] then
		IgnoreFolder = Instance_("Folder")
		IgnoreFolder:AddTag(TAG)
		IgnoreFolder.Name = "RainIgnorance"
		IgnoreFolder.Parent = workspace.Terrain
	end
end

--// ===================== RAYCAST PARAMS =====================
local RayParams = RaycastParams.new()
RayParams.IgnoreWater = false
RayParams.RespectCanCollide = false

local IgnoreInstances = {}
local function UpdateRaycastParams()
	local List = IgnoreInstances
	for _,v in {IgnoreFolder, workspace.CurrentCamera, Players.LocalPlayer and Players.LocalPlayer.Character} do
		TableInsert_(List, v)
	end
	if Module.Settings.ExcludeInstances then
		for _, inst in Module.Settings.ExcludeInstances do
			TableInsert_(List, inst)
		end
	end
	RayParams.ExcludeInstances = List
end
UpdateRaycastParams()

--// ===================== VALIDATION HELPER =====================

local function CheckType(value, expected, fnName)
	if typeof(value) ~= expected then
		error(string.format("%s expects a %s, got %s", fnName, expected, typeof(value)), 3)
	end
end

--// ===================== STORE USED ATTACHMENTS =====================
local TopAttachmentTemplates, BottomAttachmentTemplates, SplashAttachmentTemplates = {}, {}, {}

--// ===================== HELPERS =====================

local function MultiplyNumberSequence(Sequence: NumberSequence, Value: number)
	local Keypoints = Sequence.Keypoints
	local NewKeypoints = table.create(#Keypoints)
	for i, Keypoint in Keypoints do
		NewKeypoints[i] = NumberSequenceKeypoint.new(Keypoint.Time, Keypoint.Value * Value, Keypoint.Envelope * Value)
	end
	return NumberSequence.new(NewKeypoints)
end

local function MultiplyTransparency(Sequence: NumberSequence, Value: number)
	local Keypoints = Sequence.Keypoints
	local NewKeypoints = table.create(#Keypoints)
	for i, Keypoint in Keypoints do
		NewKeypoints[i] = NumberSequenceKeypoint.new(Keypoint.Time, Keypoint.Value * (1-Value) + Value, Keypoint.Envelope * Value)
	end
	return NumberSequence.new(NewKeypoints)
end

local StoreTransparencySequences = {} -- Stores transparency sequences for reuse
local function GenerateTransparencySequences(Object: Beam | ParticleEmitter, StartValue: number, EndValue: number, SequenceFrames: number): {NumberSequence}
	local objectType = Object.ClassName
	local AnimationKey = tostring(StartValue) .. Module.Settings.Weather .. objectType .. tostring(EndValue)
	if StoreTransparencySequences[AnimationKey] then
		return StoreTransparencySequences[AnimationKey]
	end
	StoreTransparencySequences[AnimationKey] = table.create(SequenceFrames)
	
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]
	local TemplateTransparency = BottomAttachmentTemplate and BottomAttachmentTemplate.Beam.Transparency or NumberSequence.new(0.5)
	local Diff = (EndValue - StartValue)
	for i=1,SequenceFrames do
		local Value = StartValue + Diff * (i / SequenceFrames)
		StoreTransparencySequences[AnimationKey][i] = {
			Sequence = MultiplyTransparency(TemplateTransparency, Value),
			Value = Value,
		}
	end
	return StoreTransparencySequences[AnimationKey]
end

local BeamTransparencyMultiplier = {} -- Stores what stage of transparency the beam is at
local function TweenSequenceTransparency(Object: Beam, Duration: number, EndValue: number, BreakFunction: (() -> boolean)?)
	local StartValue = BeamTransparencyMultiplier[Object] and MathRound_(BeamTransparencyMultiplier[Object]*10)/10 or 1
	local SequenceFrames = 1 + MathFloor_(0.5 + MathAbs_(EndValue - StartValue)*2)
	
	local TransparencySequences = GenerateTransparencySequences(Object, StartValue, EndValue, SequenceFrames)
	
	local TimeElapsed = 0
	while TimeElapsed < Duration do
		if BreakFunction and BreakFunction() then
			break
		end
		
		local Index = 1 + MathFloor_(SequenceFrames * (TimeElapsed/Duration))
		
		Object.Transparency = TransparencySequences[Index].Sequence
		BeamTransparencyMultiplier[Object] = TransparencySequences[Index].Value
		
		TimeElapsed += RunService.RenderStepped:Wait()
	end
end

-- FOR CLEANUP, SPEEDS UP SIGNIFICANTLY
local function BulkTweenSequenceTransparency(Objects: {Beam}, Duration: number, EndValue: number, FinishFunction: ((Beam, boolean) -> nil)?, BreakFunction: (() -> boolean?)?)
	local ObjectSequenceLengths = table.create(#Objects)
	local ObjectTransparencySequences = table.create(#Objects)
	
	for i,Object in Objects do
		local StartValue = BeamTransparencyMultiplier[Object] and MathRound_(BeamTransparencyMultiplier[Object]*10)/10 or 1
		ObjectSequenceLengths[i] = 1 + MathFloor_(0.5 + MathAbs_(EndValue - StartValue)*2)
		ObjectTransparencySequences[i] = GenerateTransparencySequences(Object, StartValue, EndValue, ObjectSequenceLengths[i])
	end
	
	local Interrupted = false
	local TimeElapsed = 0
	while TimeElapsed < Duration do
		if BreakFunction and BreakFunction() then
			Interrupted = true
			break
		end
		
		local Percentage = (TimeElapsed/Duration)
		for i, Object in Objects do
			local Index = 1 + MathFloor_(ObjectSequenceLengths[i] * Percentage)
			
			Object.Transparency = ObjectTransparencySequences[i][Index].Sequence
			BeamTransparencyMultiplier[Object] = ObjectTransparencySequences[i][Index].Value
		end
		TimeElapsed += RunService.RenderStepped:Wait()
	end
	if FinishFunction then
		for i,Object in Objects do
			FinishFunction(Object, Interrupted)
		end
	end
end

local function GetDirection()
	local WindVector = workspace.GlobalWind/20
	return (Module.Settings.Direction.Unit + WindVector * Module.Settings.WindInfluence).Unit
end

--// ===================== Pre-load Assets =====================
local function PreloadAssets()
	local TemporaryAssets = {}
	for _, Constructor in Constructors:GetChildren() do
		local ConstructorData = require(Constructor)
		local A1,A2,A3 = ConstructorData.Constructor()
		local Attachments = {A1,A2,A3}
		for _,Attachment in Attachments do
			for _,v in Attachment:GetDescendants() do
				if v:IsA("Sound") or v:IsA("ParticleEmitter") or v:IsA("Beam") then
					table.insert(TemporaryAssets, v)
				end
			end
		end
		for _,Attachment in Attachments do
			Attachment:Destroy()
		end
	end
	
	task.spawn(function()
		ContentProvider:PreloadAsync(TemporaryAssets)
		
		for _,instance in TemporaryAssets do -- No longer needed
			instance:Destroy()
		end
	end)
end
PreloadAssets() -- Preload assets to avoid beam texture showing white

--// ===================== ATTACHMENT POOL =====================

local TotalAttachmentPairs = {}
local ActiveQueue = {}
local SplashAttachments = {}
local function CreateAttachmentPair(key: string)
	Module.AttachmentCounter.Value += 1

	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]

	local TemplateMist = TopAttachmentTemplate.Mist
	local TemplateBeam = BottomAttachmentTemplate.Beam
	local TemplateSplash = BottomAttachmentTemplate.Splash

	local VisualHeightMul = Module.Settings.VisualHeight/80
	
	local UseTimeScale = Module.Settings.Speed < 1
	local TimeScale = UseTimeScale and Module.Settings.Speed or 1
	local SpeedScale = UseTimeScale and 1 or Module.Settings.Speed

	local MistTransparency = MultiplyTransparency(TemplateMist.Transparency, Module.Settings.Transparency)
	local MistSize = MultiplyNumberSequence(TemplateMist.Size, Module.Settings.Scale)
	local MistLifetime = NumberRange.new(TemplateMist.Lifetime.Min/SpeedScale/(Module.Settings.ExtraMistParticles+1), TemplateMist.Lifetime.Max/SpeedScale/(Module.Settings.ExtraMistParticles+1))
	local MistSpeed = NumberRange.new(VisualHeightMul*TemplateMist.Speed.Min*SpeedScale, VisualHeightMul*TemplateMist.Speed.Max*SpeedScale)
	local MistAcceleration = VisualHeightMul * TemplateMist.Acceleration * SpeedScale

	local BeamTransparency = MultiplyTransparency(TemplateBeam.Transparency, Module.Settings.Transparency)
	local BeamTextureLength = VisualHeightMul*TemplateBeam.TextureLength
	local BeamTextureSpeed = TemplateBeam.TextureSpeed * Module.Settings.Speed
	local BeamWidth0 = TemplateBeam.Width0 * Module.Settings.Scale
	local BeamWidth1 = TemplateBeam.Width1 * Module.Settings.Scale

	local SplashTransparency = MultiplyTransparency(TemplateSplash.Transparency, Module.Settings.Transparency)
	local SplashRate = TemplateSplash.Rate*SpeedScale
	local SplashSize = MultiplyNumberSequence(TemplateSplash.Size, Module.Settings.Scale)
	local SplashLifetime = NumberRange.new(TemplateSplash.Lifetime.Min/SpeedScale, TemplateSplash.Lifetime.Max/SpeedScale)

	local ParticleColor = ColorSequence.new(Module.Settings.Color)
	local LightEmission = Module.Settings.LightEmission
	local LightInfluence = Module.Settings.LightInfluence
	local Brightness = Module.Settings.Brightness
	local BeamEffectEnabled = Module.Settings.BeamEffect

	if not TotalAttachmentPairs[Module.Settings.Weather] then
		TotalAttachmentPairs[Module.Settings.Weather] = {}
	end

	local TopClone = TopAttachmentTemplate:Clone(); TopClone:AddTag(INSTANCE_TAG)
	local BottomClone = BottomAttachmentTemplate:Clone(); BottomClone:AddTag(INSTANCE_TAG)
	local ExtraClones = table.create(Module.Settings.ExtraMistParticles)
	
	TopClone.Archivable = false
	BottomClone.Archivable = false
	
	for i=1, Module.Settings.ExtraMistParticles do
		local ExtraClone = TopAttachmentTemplate:Clone(); ExtraClone:AddTag(INSTANCE_TAG)
		ExtraClone.Name = "Extra"
		ExtraClone.Mist.TimeScale = TimeScale
		ExtraClone.Mist.Lifetime = MistLifetime
		ExtraClone.Mist.Speed = MistSpeed
		ExtraClone.Mist.Acceleration = MistAcceleration
		ExtraClone.Mist.Size = MistSize
		ExtraClone.Mist.Color = ParticleColor
		ExtraClone.Mist.Transparency = MistTransparency
		ExtraClone.Mist.LightEmission = LightEmission
		ExtraClone.Mist.LightInfluence = LightInfluence
		ExtraClone.Mist.Brightness = Brightness
		if i == Module.Settings.ExtraMistParticles then -- Last one should face camera to avoid looking too 'flat'
			ExtraClone.Mist.Orientation = Enum.ParticleOrientation.FacingCamera
		end
		
		ExtraClone.Archivable = false
		ExtraClone.Parent = IgnoreFolder
		ExtraClones[i] = ExtraClone
	end

	TopClone.Parent = IgnoreFolder
	BottomClone.Parent = IgnoreFolder

	local Beam = BottomClone.Beam
	Beam.Attachment0 = TopClone
	Beam.Attachment1 = BottomClone
	Beam.Width0 = BeamWidth0
	Beam.Width1 = BeamWidth1
	Beam.TextureLength = BeamTextureLength
	Beam.TextureSpeed = BeamTextureSpeed
	Beam.Color = ParticleColor
	Beam.Transparency = BeamTransparency
	BeamTransparencyMultiplier[Beam] = 0
	Beam.LightEmission = LightEmission
	Beam.LightInfluence = LightInfluence
	Beam.Brightness = Brightness
	Beam.Enabled = BeamEffectEnabled

	local Splash = BottomClone.Splash
	Splash.TimeScale = Module.Settings.Speed
	Splash.Lifetime = SplashLifetime
	Splash.Size = SplashSize
	Splash.Color = ParticleColor
	Splash.Rate = SplashRate
	Splash.Transparency = SplashTransparency
	Splash.LightEmission = LightEmission
	Splash.LightInfluence = LightInfluence
	Splash.Brightness = LightEmission
	
	TopClone.Mist.TimeScale = Module.Settings.Speed
	TopClone.Mist.Lifetime = MistLifetime
	TopClone.Mist.Speed = MistSpeed
	TopClone.Mist.Acceleration = MistAcceleration
	TopClone.Mist.Size = MistSize
	TopClone.Mist.Color = ParticleColor
	TopClone.Mist.Transparency = MistTransparency
	TopClone.Mist.LightEmission = LightEmission
	TopClone.Mist.LightInfluence = LightInfluence
	TopClone.Mist.Brightness = LightEmission

	TotalAttachmentPairs[Module.Settings.Weather][key] = {TopClone, BottomClone, ExtraClones}

	return TotalAttachmentPairs[Module.Settings.Weather][key]
end

local MaxAttachments = 0
local CurrentAttachmentIndex = 0
local function GetAttachmentPair()
	CurrentAttachmentIndex += 1
	if CurrentAttachmentIndex > MaxAttachments then
		CurrentAttachmentIndex = 1
	end
	local key = tostring(CurrentAttachmentIndex)
	if not TotalAttachmentPairs[Module.Settings.Weather] or not TotalAttachmentPairs[Module.Settings.Weather][key] then
		return CreateAttachmentPair(key), key
	end
	return TotalAttachmentPairs[Module.Settings.Weather][key], key
end

--// Tweens active beams to become invisible
local function CleanupAttachments()
	local CurrentWeather = Module.Settings.Weather
	
	local Beams = {}
	local Attachments = {}
	for key, pair in ActiveQueue do
		if not pair[2] or not pair[2].Parent then continue end
		pair[1].Mist.Enabled = false
		pair[2].Splash.Enabled = false
		
		TableInsert_(Beams, pair[2].Beam)
		
		TotalAttachmentPairs[CurrentWeather][key] = pair
	end
	task.spawn(function()
		BulkTweenSequenceTransparency(Beams, Module.Settings.FadeOutTime, 1, function(Beam, Interrupted)
			Beam.Enabled = false
		end)
	end)
	ActiveQueue = {}
end

--// ===================== SOUND =====================

local SOUND_PART_MESH_ID = "rbxassetid://77128059060400"
local BackgroundAmbienceSounds = {}
local SoundScanGrid = {}

local function RecomputeSoundScanGrid(template: string)
	local SoundPositionOffsets = SoundGrids[template]
	SoundScanGrid = {}
	for i=1,#SoundPositionOffsets do
		SoundScanGrid[i] = SoundPositionOffsets[i] * Module.Settings.DynamicSoundRadius
	end
	table.sort(SoundScanGrid, function(a, b)
		return a.Magnitude < b.Magnitude
	end)
end
RecomputeSoundScanGrid(Module.Settings.SoundGrid)

local SoundGridPartContainersConfig = {
	{"SoundGridPartsInside", Color3.new(0,1,0), 0},
	{"SoundGridPartsClosest", Color3.new(0,1,1), 0},
	{"SoundGridPartsOutside", Color3.new(1,0,0), 0},
}
local SoundGridParts = {}
local SoundGridPartModels = {}

local function UpdateSoundGridModels()
	local NewContainers = {}
	for _, v in SoundGridPartContainersConfig do
		local Name =  v[1]
		local Color = v[2]
		local FillTransparency = v[3]
		local Container = Instance_("Model")
		Container.Name = Name
		local Highlight = Instance_("Highlight")
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Highlight.FillTransparency = FillTransparency
		Highlight.FillColor = Color
		Highlight.OutlineTransparency = 1
		Highlight.Parent = Container
		Container.Archivable = false
		Container.Parent = IgnoreFolder
		NewContainers[Name] = Container
	end
	
	for _, v in SoundGridParts do -- Move old parts to newer models
		if not v or not v.Parent then continue end
		v.Parent = NewContainers["SoundGridPartsOutside"]
	end
	for _, v in SoundGridPartModels do -- Destroy old models
		v:Destroy()
	end
	SoundGridPartModels = NewContainers
end

local function GetMinSoundDistance()
	local Cam = workspace.CurrentCamera
	if not Cam then warn("GetMinSoundDistance: No camera found") return Module.Settings.DynamicSoundRadius, false end

	local RainDir = -GetDirection() * Module.Settings.RaycastHeight/2
	local CameraOrigin = Cam.CFrame.Position
	
	local Inside = true
	for _, v in SoundScanGrid do
		local VolumePosition = CameraOrigin + v
		local RaycastResult1 = workspace:Raycast(VolumePosition, RainDir, RayParams)
		local RaycastResult2 = workspace:Raycast(CameraOrigin, (VolumePosition - CameraOrigin).Unit*Module.Settings.DynamicSoundRadius, RayParams)
		if not RaycastResult1 and not RaycastResult2 then
			Inside = false
			break
		end
	end
	local BreakPart = 0
	local MinDistance = Module.Settings.DynamicSoundRadius
	for i, v in SoundScanGrid do
		local Pos = CameraOrigin+v
		if not workspace:Raycast(Pos, RainDir, RayParams) and not workspace:Raycast(Pos+RainDir, -RainDir, RayParams) then
			MinDistance = v.Magnitude
			BreakPart = i
			break
		end
	end
	
	if Module.Settings.VisualizeSoundGrid then
		for i, v in SoundScanGrid do
			local Part = SoundGridParts[i]
			if not Part or not Part.Parent then
				Part = Instance_("Part")
				Part.Size = Vector3_(0.2,0.2,1)
				Part.Transparency = 0
				Part.Name = "SoundGridPart"
				Part.Anchored = true
				Part.Locked = true
				Part.CanCollide = false
				Part.CanTouch = false
				Part.CanQuery = false
				local Mesh = Instance_("SpecialMesh")
				Mesh.Scale = Vector3_(0.3,0.3,0.3)
				Mesh.MeshType = Enum.MeshType.FileMesh
				Mesh.MeshId = SOUND_PART_MESH_ID
				Mesh.Parent = Part
			end
			Part.Parent = i == BreakPart and SoundGridPartModels.SoundGridPartsClosest or
				i < BreakPart and SoundGridPartModels.SoundGridPartsInside or
				SoundGridPartModels.SoundGridPartsOutside
			Part.CFrame = CFrame_(CameraOrigin + v, CameraOrigin + v + RainDir)
			SoundGridParts[i] = Part
		end
	end

	return MinDistance, Inside
end

local function CreateSound()
	local AmbienceSound = Instance_("Sound")
	AmbienceSound.Name = "WeatherBackgroundAmbienceSound"
	AmbienceSound.SoundId = Module.Settings.SoundId
	AmbienceSound.Looped = true
	AmbienceSound.PlaybackSpeed = 0.8
	AmbienceSound.Volume = 0
	AmbienceSound.Parent = Module.Settings.SoundParent or SoundService
	
	local Equalizer = AmbienceSound:FindFirstChild("Equalizer") or Instance_("EqualizerSoundEffect")
	Equalizer.Name = "Equalizer"
	Equalizer.HighGain = 0
	Equalizer.MidGain = 0
	Equalizer.LowGain = 0
	Equalizer.Parent = AmbienceSound

	BackgroundAmbienceSounds[Module.Settings.Weather] = AmbienceSound
	return AmbienceSound
end

local function GetSound()
	if not Module.Settings.Weather then return end

	local Sound = BackgroundAmbienceSounds[Module.Settings.Weather]
	if not Sound then
		Sound = CreateSound()
	end

	local Equalizer = Sound.Equalizer
	return Sound, Equalizer
end

local LastGain = 0.01
local EqualizerTween = TweenInfo.new(0.8)
local function ApplyStaticSound()
	local AmbienceSound, Equalizer = GetSound()
	TweenService:Create(AmbienceSound, EqualizerTween, {Volume = Module.Settings.SoundVolume * 0.15}):Play()
	TweenService:Create(Equalizer, EqualizerTween, {HighGain = -2}):Play()
	LastGain = 0.01
end

local function UpdateSound(Bypass)
	local MinDistance, Inside = GetMinSoundDistance()
	local DistanceFactor = (1 - MinDistance/Module.Settings.DynamicSoundRadius)
	
	local Gain = (Inside and -12 or 0) - 24*(1-DistanceFactor)
	if Gain == LastGain and not Bypass then return end
	local AmbienceSound, Equalizer = GetSound()
	local Volume = Module.Settings.SoundVolume * math.max((Inside and -0.04 or 0) + 0.2*DistanceFactor, 0)
	
	TweenService:Create(AmbienceSound, EqualizerTween, {Volume = Volume}):Play()
	TweenService:Create(Equalizer, EqualizerTween, {HighGain = Gain}):Play()

	LastGain = Gain
end
local function PlaySound()
	local AmbienceSound, Equalizer = GetSound()
	if not AmbienceSound then return end

	if AmbienceSound.IsPlaying then return end
	AmbienceSound.Volume = 0
	AmbienceSound.TimePosition = math.random()*AmbienceSound.TimeLength
	AmbienceSound:Play()

	LastGain = 0.01
end
local function StopSound()
	local AmbienceSound, Equalizer = GetSound()
	if not AmbienceSound then return end

	local Tween = TweenService:Create(AmbienceSound, EqualizerTween, {Volume = 0})
	Tween:Play()
	TweenService:Create(Equalizer, EqualizerTween, {HighGain = 0}):Play()
	LastGain = 0.01

	Tween.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Cancelled then return end
		AmbienceSound:Stop()
	end)
end

--// ===================== LIVE SETTING CHANGES =====================
local MaxSplashAttachments = 0
local function UpdateMaxSplashAttachments()
	local SplashAttachmentTemplate = SplashAttachmentTemplates[Module.Settings.Weather]
	if not SplashAttachmentTemplate then return end
	if not SplashAttachmentTemplate:FindFirstChild("Splash") then return end

	local Splash = SplashAttachmentTemplate.Splash
	local Duration = Splash.Lifetime.Max/Module.Settings.Speed

	MaxSplashAttachments = Module.Settings.PartLockedSplash and math.ceil((1 + Duration) * Module.Settings.SplashIntensity) or Module.Settings.SplashIntensity * 20/120
end

local UpdatingWeather = false -- Prevents race conditions
local function UpdateWeather(weather)
	if UpdatingWeather then return end
	UpdatingWeather = true

	local FindWeather = Constructors:FindFirstChild(weather)
	if not FindWeather then
		warn("SetWeather: '" .. weather .. "' is not a valid weather.")
		UpdatingWeather = false
		return
	end
	local GetWeather = require(FindWeather)

	local WasRunning = Module.Running
	if WasRunning then
		RunToken += 1 -- Prevents MainLoop cleanup
		Module:Stop() -- Stop all current operations

		-- Cleanup required before weather is changed
		CleanupAttachments()
		StopSound()
	end
	
	if not TopAttachmentTemplates[weather] then
		local TopAttachmentTemplate, BottomAttachmentTemplate, SplashAttachmentTemplate = GetWeather.Constructor()
		
		TopAttachmentTemplates[weather] = TopAttachmentTemplate
		BottomAttachmentTemplates[weather] = BottomAttachmentTemplate
		SplashAttachmentTemplates[weather] = SplashAttachmentTemplate
		
		TopAttachmentTemplate.Name = "TopAttachment_" .. weather
		BottomAttachmentTemplate.Name = "BottomAttachment_" .. weather
		SplashAttachmentTemplate.Name = "SplashAttachment_" .. weather
		
		TopAttachmentTemplate.Parent = script
		BottomAttachmentTemplate.Parent = script
		SplashAttachmentTemplate.Parent = script
	end
	
	Module.Settings.Weather = weather
	
	-- Reparent for use --
	if not TotalAttachmentPairs[weather] then
		TotalAttachmentPairs[weather] = {}
	end
	for _,pair in TotalAttachmentPairs[weather] do
		local TopAttachment,BottomAttachment,ExtraAttachments = pair[1], pair[2], pair[3]
		TopAttachment.Parent = IgnoreFolder
		BottomAttachment.Parent = IgnoreFolder
		for _,extra in ExtraAttachments do
			extra.Parent = IgnoreFolder
		end
	end
	
	for setting, value in GetWeather.Settings do
		if Module.Settings[setting] ~= nil then
			if not Module["Set"..setting] then warn("Could not find function'"..("Set"..setting).."'") continue end
			Module["Set"..setting](nil, value) -- Updates settings
		end
	end

	if WasRunning then
		Module:Start()
	end
	UpdatingWeather = false
end

local function UpdateScale()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end

	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]
	local SplashAttachmentTemplate = SplashAttachmentTemplates[Module.Settings.Weather]

	local TemplateBeam = BottomAttachmentTemplate.Beam
	local TemplateSplash = BottomAttachmentTemplate.Splash
	local TemplateMist = TopAttachmentTemplate.Mist
	local TemplateStandaloneSplash = SplashAttachmentTemplate.Splash

	local SplashSize = MultiplyNumberSequence(TemplateSplash.Size, Module.Settings.Scale)
	local MistSize = MultiplyNumberSequence(TemplateMist.Size, Module.Settings.Scale)
	local StandaloneSplashSize = MultiplyNumberSequence(TemplateStandaloneSplash.Size, Module.Settings.Scale)

	local BeamWidth0 = TemplateBeam.Width0 * Module.Settings.Scale
	local BeamWidth1 = TemplateBeam.Width1 * Module.Settings.Scale

	local function SetPair(pair)
		pair[2].Beam.Width0 = BeamWidth0
		pair[2].Beam.Width1 = BeamWidth1
		pair[2].Splash.Size = SplashSize
		pair[1].Mist.Size = MistSize

		for _, extra in pair[3] do
			extra.Mist.Size = MistSize
		end
	end
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Size = StandaloneSplashSize
		end
	end
end

local function UpdateVisualHeight()
	if not TotalAttachmentPairs[Module.Settings.Weather] then return end

	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]

	local TemplateBeam = BottomAttachmentTemplate.Beam
	local TemplateMist = TopAttachmentTemplate.Mist

	local VisualHeightMul = Module.Settings.VisualHeight/80
	
	local UseTimeScale = Module.Settings.Speed < 1
	local TimeScale = UseTimeScale and 1 or Module.Settings.Speed
	
	local BeamTextureLength = VisualHeightMul * TemplateBeam.TextureLength
	local MistSpeed = NumberRange.new(VisualHeightMul*TemplateMist.Speed.Min*TimeScale, VisualHeightMul*TemplateMist.Speed.Max*TimeScale)
	local MistAcceleration = VisualHeightMul * TemplateMist.Acceleration * TimeScale

	local function SetPair(pair)
		pair[2].Beam.TextureLength = BeamTextureLength
		pair[1].Mist.Acceleration = MistAcceleration
		pair[1].Mist.Speed = MistSpeed
		
		if UseTimeScale then
			pair[1].Mist.TimeScale = Module.Settings.Speed
			for _, extra in pair[3] do
				extra.Mist.TimeScale = Module.Settings.Speed
			end
		end

		for _, extra in pair[3] do
			extra.Mist.Speed = MistSpeed
			extra.Mist.Acceleration = MistAcceleration
		end
	end
	
	for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
		SetPair(pair)
	end
end

local function UpdateExtraMistParticles()
	if not TotalAttachmentPairs[Module.Settings.Weather] then return end
	
	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local ExtraMistParticles = Module.Settings.ExtraMistParticles
	
	local function CreateNewExtra(pair, N: number)
		Module.AttachmentCounter.Value += 1
		for i=1, N do
			local ExtraClone = TopAttachmentTemplate:Clone(); ExtraClone:AddTag(INSTANCE_TAG)
			ExtraClone.Name = "Extra"
			ExtraClone.Mist.Lifetime = pair[1].Mist.Lifetime
			ExtraClone.Mist.Speed = pair[1].Mist.Speed
			ExtraClone.Mist.Acceleration = pair[1].Mist.Acceleration
			ExtraClone.Mist.Size = pair[1].Mist.Size
			ExtraClone.Mist.Color = pair[1].Mist.Color
			ExtraClone.Mist.Transparency = pair[1].Mist.Transparency
			ExtraClone.Mist.LightEmission = pair[1].Mist.LightEmission
			ExtraClone.Mist.LightInfluence = pair[1].Mist.LightInfluence
			ExtraClone.Mist.Brightness = pair[1].Mist.Brightness
			ExtraClone.Parent = IgnoreFolder
			table.insert(pair[3], ExtraClone)
		end
	end
	
	local function HandlePair(pair)
		local ExtraClonesCount = #pair[3]
		local Missing = ExtraMistParticles - ExtraClonesCount
		if Missing > 0 then
			CreateNewExtra(pair, Missing)
		elseif Missing < 0 then
			Module.AttachmentCounter.Value -= ExtraClonesCount
			for i=1, ExtraClonesCount do -- Remove old clones
				pair[3][i]:Destroy()
			end
			pair[3] = {}
			CreateNewExtra(pair, ExtraMistParticles)
		end
	end
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			HandlePair(pair)
		end
	end
end

local function UpdateSpeed()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end
	
	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]
	local SplashAttachmentTemplate = SplashAttachmentTemplates[Module.Settings.Weather]

	local TemplateBeam = BottomAttachmentTemplate.Beam
	local TemplateSplash = BottomAttachmentTemplate.Splash
	local TemplateMist = TopAttachmentTemplate.Mist
	local TemplateStandaloneSplash = SplashAttachmentTemplate.Splash

	local VisualHeightMul = Module.Settings.VisualHeight/80
	
	local UseTimeScale = Module.Settings.Speed <= 1
	local TimeScale = UseTimeScale and Module.Settings.Speed or 1
	local SpeedScale = UseTimeScale and 1 or Module.Settings.Speed

	local BeamTextureLength = VisualHeightMul*TemplateBeam.TextureLength
	local BeamTextureSpeed = TemplateBeam.TextureSpeed*Module.Settings.Speed
	local SplashLifetime = NumberRange.new(TemplateSplash.Lifetime.Min/SpeedScale, TemplateSplash.Lifetime.Max/SpeedScale)
	local SplashRate = TemplateSplash.Rate*SpeedScale
	local StandaloneSplashLifetime = NumberRange.new(TemplateStandaloneSplash.Lifetime.Min/SpeedScale, TemplateStandaloneSplash.Lifetime.Max/SpeedScale)
	local MistLifetime = NumberRange.new(TemplateMist.Lifetime.Min/SpeedScale/(Module.Settings.ExtraMistParticles+1), TemplateMist.Lifetime.Max/SpeedScale/(Module.Settings.ExtraMistParticles+1))
	local MistSpeed = NumberRange.new(VisualHeightMul*TemplateMist.Speed.Min*SpeedScale, VisualHeightMul*TemplateMist.Speed.Max*SpeedScale) 
	local MistAcceleration = VisualHeightMul * TemplateMist.Acceleration * SpeedScale

	local function SetPair(pair)
		pair[2].Beam.TextureLength = BeamTextureLength
		pair[2].Beam.TextureSpeed = BeamTextureSpeed
		pair[2].Splash.Lifetime = SplashLifetime
		pair[2].Splash.Rate = SplashRate

		pair[1].Mist.Lifetime = MistLifetime
		pair[1].Mist.Speed = MistSpeed
		pair[1].Mist.Acceleration = MistAcceleration
		
		pair[2].Splash.TimeScale = TimeScale
		pair[1].Mist.TimeScale = TimeScale
		for _, extra in pair[3] do
			extra.Mist.TimeScale = TimeScale
		end

		for _, extra in pair[3] do
			extra.Mist.Lifetime = MistLifetime
			extra.Mist.Speed = MistSpeed
			extra.Mist.Acceleration = MistAcceleration
		end
	end
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then 
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Lifetime = StandaloneSplashLifetime
		end
	end
end

local function UpdateColor()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end
	
	local Color = ColorSequence.new(Module.Settings.Color)

	local function SetPair(pair)
		pair[2].Beam.Color = Color
		pair[2].Splash.Color = Color
		pair[1].Mist.Color = Color

		for _, extra in pair[3] do
			extra.Mist.Color = Color
		end
	end
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Color = Color
		end
	end
end

local function UpdateTransparency()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end
	
	local TopAttachmentTemplate = TopAttachmentTemplates[Module.Settings.Weather]
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]
	local SplashAttachmentTemplate = SplashAttachmentTemplates[Module.Settings.Weather]

	local BeamTransparency = MultiplyTransparency(BottomAttachmentTemplate.Beam.Transparency, Module.Settings.Transparency)
	local MistTransparency = MultiplyTransparency(TopAttachmentTemplate.Mist.Transparency, Module.Settings.Transparency)
	local SplashTransparency = MultiplyTransparency(BottomAttachmentTemplate.Splash.Transparency, Module.Settings.Transparency)
	local StandaloneSplashTransparency = MultiplyTransparency(SplashAttachmentTemplate.Splash.Transparency, Module.Settings.Transparency)

	local function SetPair(pair)
		pair[2].Beam.Transparency = BeamTransparency
		BeamTransparencyMultiplier[pair[2].Beam] = Module.Settings.Transparency
		pair[2].Splash.Transparency = SplashTransparency
		pair[1].Mist.Transparency = MistTransparency

		for _, extra in pair[3] do
			extra.Mist.Transparency = MistTransparency
		end
	end
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Transparency = StandaloneSplashTransparency
		end
	end
end

local function UpdateFadeInTime() -- Only needed if fade in is 0 (not used)
	if not TotalAttachmentPairs[Module.Settings.Weather] then return end
	if Module.Settings.FadeInTime > 0 then return end
	
	local BottomAttachmentTemplate = BottomAttachmentTemplates[Module.Settings.Weather]
	local BeamTransparency = MultiplyTransparency(BottomAttachmentTemplate.Beam.Transparency, Module.Settings.Transparency)
	
	local function SetPair(pair)
		pair[2].Beam.Transparency = BeamTransparency
		BeamTransparencyMultiplier[pair[2].Beam] = Module.Settings.Transparency
	end
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
end

local function UpdateLightInfluence()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end
	
	local function SetPair(pair)
		pair[2].Beam.LightInfluence = Module.Settings.LightInfluence
		pair[2].Splash.LightInfluence = Module.Settings.LightInfluence
		pair[1].Mist.LightInfluence = Module.Settings.LightInfluence
		for _, extra in pair[3] do
			extra.Mist.LightInfluence = Module.Settings.LightInfluence
		end
	end
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.LightInfluence = Module.Settings.LightInfluence
		end
	end
end

local function UpdateBrightness()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end

	local function SetPair(pair)
		pair[2].Beam.Brightness = Module.Settings.Brightness
		pair[2].Splash.Brightness = Module.Settings.Brightness
		pair[1].Mist.Brightness = Module.Settings.Brightness
		for _, extra in pair[3] do
			extra.Mist.Brightness = Module.Settings.Brightness
		end
	end
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Brightness = Module.Settings.Brightness
		end
	end
end

local function UpdateLightEmission()
	if not TotalAttachmentPairs[Module.Settings.Weather] and not SplashAttachments[Module.Settings.Weather] then return end
	
	local function SetPair(pair)
		pair[2].Beam.LightEmission = Module.Settings.LightEmission
		pair[2].Splash.LightEmission = Module.Settings.LightEmission
		pair[1].Mist.LightEmission = Module.Settings.LightEmission
		for _, extra in pair[3] do
			extra.Mist.LightEmission = Module.Settings.LightEmission
		end
	end
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			SetPair(pair)
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.LightEmission = Module.Settings.LightEmission
		end
	end
end

local function UpdateMaxAttachments()
	local RainDuration = (Module.Settings.FadeInTime + Module.Settings.FadeOutTime + Module.Settings.BeamDuration) / Module.Settings.Speed
	MaxAttachments = math.ceil((1 + RainDuration) * Module.Settings.Intensity)
end

--// ===================== VISUALIZATION =====================
local SnowifiedParts = {}
local function SnowifyBasePart(Part: BasePart, Direction: Vector3)
	if Part:IsA("Terrain") then return end
	if Part.Transparency >= 1 then return end
	if Part:HasTag(Module.Settings.IgnoreSnowTag) then return end
	if Part:HasTag("__HAS_SNOW_LAYER") then return end
	Part:AddTag("__HAS_SNOW_LAYER")
	
	Direction = Vector3_(0,1,0) -- Remove this line if snow layers should be directional

	local MinSize = math.min(0.5, Part.Size.X, Part.Size.Y, Part.Size.Z)

	local SnowPart = Part:Clone(); SnowPart:AddTag(INSTANCE_TAG)
	local OriginalSize = SnowPart.Size
	if SnowPart:IsA("MeshPart") then
		SnowPart.TextureID = ""
	end
	SnowPart:ClearAllChildren()
	SnowPart.Name = "Snow"..Part.Name
	SnowPart.CastShadow = false
	SnowPart.Transparency = 0
	SnowPart.Anchored = true
	SnowPart.CanCollide = false
	SnowPart.CanQuery = false
	SnowPart.CanTouch = false
	SnowPart.Material = Enum.Material.Snow
	SnowPart.Color = Color3.fromRGB(255,255,255)
	SnowPart.CFrame = Part.CFrame
	SnowPart.Size = OriginalSize - Vector3_(0.1,0.1,0.1)
	SnowPart.Archivable = false
	SnowPart.Parent = IgnoreFolder

	TweenService:Create(SnowPart, TweenInfo.new(2), {Size = OriginalSize - Vector3_(0.01,0.01,0.01), CFrame = Part.CFrame + Direction.Unit*(MinSize+MathRandom_(-100,100)/10000)}):Play()

	TableInsert_(SnowifiedParts, {SnowPart, Part})
end

local InvisibleTransparencySequence = NumberSequence.new(1)
local function CreateRain(RayData)
	local AttachmentPair, AttachmentIndex = GetAttachmentPair()
	if ActiveQueue[AttachmentIndex] then return end
	if not AttachmentPair[1] or not AttachmentPair[1].Parent then return end
	
	-- Save current state
	local SaveWeather = Module.Settings.Weather
	local SaveRunToken = RunToken

	ActiveQueue[AttachmentIndex] = AttachmentPair -- Locks attachment pair

	local BottomCFrame = CFrame_(RayData.HitPosition, RayData.HitPosition + RayData.Normal) * CFrameAngles_(MathRad_(90),0,0)
	local TopCFrame = CFrame_(BottomCFrame.Position - RayData.Direction * Module.Settings.VisualHeight, RayData.HitPosition)
	
	-- Attachments --
	local TopAttachment = AttachmentPair[1]
	local BottomAttachment = AttachmentPair[2]
	local ExtraAttachments = AttachmentPair[3]
	
	-- Effects --
	local TopMist = TopAttachment.Mist
	local RainBeam = BottomAttachment.Beam
	local BottomSplash = BottomAttachment.Splash

	local FadeOutAbove0 = Module.Settings.FadeOutTime > 0
	local FadeInAbove0 = Module.Settings.FadeInTime > 0
	
	local BottomTemplateAttachment = BottomAttachmentTemplates[SaveWeather]
	if not FadeInAbove0 and FadeOutAbove0 then
		RainBeam.Transparency = MultiplyTransparency(BottomTemplateAttachment.Beam.Transparency, Module.Settings.Transparency)
	elseif FadeInAbove0 and not FadeOutAbove0 then
		RainBeam.Transparency = InvisibleTransparencySequence
	end
	
	if Module.Settings.BeamEffect then
		RainBeam.Enabled = Module.Settings.BeamEffect
	end
	
	TopAttachment.WorldCFrame = TopCFrame
	BottomAttachment.WorldCFrame = BottomCFrame
	
	if Module.Settings.MistParticles then
		TopMist:Emit(1)
		for i, extra in ExtraAttachments do
			extra.WorldCFrame = TopCFrame * CFrame_(0,0,-i*Module.Settings.VisualHeight/(1+Module.Settings.ExtraMistParticles))
			extra.Mist:Emit(1)
		end
	end
	if RayData.IncludeDroplet and Module.Settings.SplashParticles and not Module.Settings.PartLockedSplash and RayData.Normal:Dot(-RayData.Direction) >= Module.Settings.SplashThreshold then
		if BottomSplash.Rate == 0 then -- Optional single splashes (used for light rain)
			BottomSplash:Emit(1)
		else
			BottomSplash.Enabled = true
		end
	else
		BottomSplash.Enabled = false
	end

	local function Abort()
		if SaveRunToken ~= RunToken then return true end
		if not Module.Running then return true end
		return false
	end

	local function Reset()
		if Abort() then return end

		BottomSplash.Enabled = false
		RainBeam.Enabled = false
		
		ActiveQueue[AttachmentIndex] = nil
	end

	if FadeOutAbove0 or FadeInAbove0 then
		TaskSpawn_(function()
			if Abort() then return end
			
			if FadeInAbove0 then
				TweenSequenceTransparency(RainBeam, Module.Settings.FadeInTime/Module.Settings.Speed, Module.Settings.Transparency, function()
					return Abort()
				end)
			end

			if Abort() then return end

			if Module.Settings.BeamDuration > 0 then
				TaskWait_(Module.Settings.BeamDuration/Module.Settings.Speed)
			end

			if Abort() then return end

			if FadeOutAbove0 then
				TweenSequenceTransparency(RainBeam, Module.Settings.FadeOutTime/Module.Settings.Speed, 1, function()
					return Abort()
				end)
			end
			
			Reset()
		end)
	else
		TaskDelay_(Module.Settings.BeamDuration > 0 and Module.Settings.BeamDuration/Module.Settings.Speed or 1/Module.Settings.Speed, Reset)
	end
end

local SplashIndex = 1
local function CreateSplash(RayData)
	if not RayData.IncludeDroplet then return end
	if not SplashAttachmentTemplates[Module.Settings.Weather] then return end
	if RayData.Normal:Dot(-RayData.Direction) < Module.Settings.SplashThreshold then return end
	if not SplashAttachments[Module.Settings.Weather] then
		SplashAttachments[Module.Settings.Weather] = {}
	end

	local Attachment = SplashAttachments[Module.Settings.Weather][tostring(SplashIndex)]
	if not Attachment or not Attachment:FindFirstChild("Splash") then
		Module.AttachmentCounter.Value += 1
		local SplashAttachmentTemplate = SplashAttachmentTemplates[Module.Settings.Weather]
		local TemplateStandaloneSplash = SplashAttachmentTemplate.Splash
		local StandaloneSplashSize = MultiplyNumberSequence(TemplateStandaloneSplash.Size, Module.Settings.Scale)
		local StandaloneSplashTransparency = MultiplyTransparency(TemplateStandaloneSplash.Transparency, Module.Settings.Transparency)
		local StandaloneSplashLifetime = NumberRange.new(TemplateStandaloneSplash.Lifetime.Min/Module.Settings.Speed, TemplateStandaloneSplash.Lifetime.Max/Module.Settings.Speed)
		local ParticleColor = ColorSequence.new(Module.Settings.Color)
		local LightEmission = Module.Settings.LightEmission
		local LightInfluence = Module.Settings.LightInfluence
		local Brightness = Module.Settings.Brightness
		
		local Clone = SplashAttachmentTemplate:Clone(); Clone:AddTag(INSTANCE_TAG)
		Clone.Splash.Size = StandaloneSplashSize
		Clone.Splash.Transparency = StandaloneSplashTransparency
		Clone.Splash.Lifetime = StandaloneSplashLifetime
		Clone.Splash.Color = ParticleColor
		Clone.Splash.LightEmission = LightEmission
		Clone.Splash.LightInfluence = LightInfluence
		Clone.Splash.Brightness = Brightness
		
		if Attachment then
			Attachment:Destroy()
		end
		SplashAttachments[Module.Settings.Weather][tostring(SplashIndex)] = Clone
		Attachment = Clone
		Clone.Archivable = false
	end
	Attachment.Parent = Module.Settings.PartLockedSplash and RayData.Instance or IgnoreFolder
	Attachment.WorldCFrame = CFrame_(RayData.HitPosition, RayData.HitPosition + RayData.Normal) * CFrameAngles_(MathRad_(90),0,0)
	Attachment.Splash.LockedToPart = Module.Settings.PartLockedSplash
	Attachment.Splash:Emit(1)

	SplashIndex += 1
	if SplashIndex > MaxSplashAttachments then
		SplashIndex = 1
	end
end

local function GenerateRays(NumberOfRays: number)
	local Cam = workspace.CurrentCamera
	if not Cam then return {} end
	
	local Rays = table.create(NumberOfRays)
	
	local SnowLayers = Module.Settings.SnowLayers
	local RandomnessValue = Module.Settings.Randomness
	local RaycastRadius = Module.Settings.RaycastRadius
	local RaycastHeight = Module.Settings.RaycastHeight
	local VisualHeight = Module.Settings.VisualHeight
	
	local Direction = GetDirection()
	
	for i=1, NumberOfRays do
		local CalcDirection = Direction
		if RandomnessValue > 0 then
			local RandomRotationAxis = Vector3_(
				MathRandom_()*2-1,
				MathRandom_()*2-1,
				MathRandom_()*2-1
			).Unit
			local RandomRotationAngle = MathRandom_(0, RandomnessValue*2*pi_)/360

			CalcDirection = Direction * cos_(RandomRotationAngle) + RandomRotationAxis:Cross(Direction) * sin_(RandomRotationAngle) + RandomRotationAxis*(RandomRotationAxis:Dot(Direction))*(1-cos_(RandomRotationAngle))
		end
		
		local RandomOffsetVector = Vector3_(
			MathRandom_(-RaycastRadius, RaycastRadius),
			MathRandom_(-RaycastRadius, RaycastRadius),
			0
		)
		
		local GetOrigin = CFrame_(Cam.CFrame.Position - CalcDirection * RaycastHeight, Cam.CFrame.Position)
		
		local RayOrigin = GetOrigin * RandomOffsetVector
		local RayDir = CalcDirection * (RaycastHeight+VisualHeight/2)
		
		local RayResult
		if Module.Settings.IgnorePartsAboveTransparency > 1 and Module.Settings.IgnorePartsWithTag == nil then
			if Module.Settings.SphereCast then
				RayResult = workspace:Spherecast(RayOrigin, Module.Settings.SphereCastRadius, RayDir, RayParams)
			else
				RayResult = workspace:Raycast(RayOrigin, RayDir, RayParams)
			end
		else
			local MaxAttempts, Attempts = 3, 0
			repeat
				Attempts += 1
				
				local InnerResult
				if Module.Settings.SphereCast then
					InnerResult = workspace:Spherecast(RayOrigin, Module.Settings.SphereCastRadius, RayDir, RayParams)
				else
					InnerResult = workspace:Raycast(RayOrigin, RayDir, RayParams)
				end
				
				if InnerResult and InnerResult.Instance  then
					if InnerResult.Instance:HasTag(Module.Settings.IgnorePartsWithTag) or InnerResult.Instance:IsA("BasePart") and InnerResult.Instance.Transparency >= Module.Settings.IgnorePartsAboveTransparency-0.001 then
						TableInsert_(IgnoreInstances, InnerResult.Instance)
						UpdateRaycastParams()
					else
						RayResult = InnerResult
					end
				else
					RayResult = InnerResult
				end
			until RayResult or Attempts >= MaxAttempts
		end

		if SnowLayers and RayResult and RayResult.Instance and RayResult.Normal.Y > 0.5 then
			SnowifyBasePart(RayResult.Instance, -RayDir)
		end

		local RayEndPosition = RayResult and RayResult.Position or RayOrigin + RayDir

		Rays[i] = {
			Origin = RayOrigin,
			Direction = CalcDirection,
			HitPosition = RayEndPosition,
			Instance = RayResult and RayResult.Instance,
			Normal = RayResult and RayResult.Normal or -CalcDirection,
			IncludeDroplet = RayResult ~= nil,
		}
	end
	return Rays
end

--// ===================== MAIN LOOP =====================

local CORE_CONNECTION = nil
local function MainLoop(Token)
	PlaySound()
	
	UpdateRaycastParams()
	
	if Module.Settings.DynamicSound and Module.Settings.DynamicSoundRadius > 0 then
		UpdateSound()
	else
		ApplyStaticSound()
	end
	
	if CORE_CONNECTION then
		CORE_CONNECTION:Disconnect()
	end
	
	local BeamsLeft = 0
	local SplashesLeft = 0
	CORE_CONNECTION = RunService.RenderStepped:Connect(function(deltaTime: number)
		debug.profilebegin("Weather")
		
		deltaTime = deltaTime * Module.Settings.Speed
		
		if Module.Settings.DynamicSound and Module.Settings.DynamicSoundRadius > 0 then
			UpdateSound()
		end
		
		if Module.Settings.Intensity > 0 and (Module.Settings.BeamEffect or Module.Settings.MistParticles) then -- if both are disabled, this is redundant
			local BeamCount = BeamsLeft + Module.Settings.Intensity * deltaTime
			local FlooredBeamCount = MathFloor_(BeamCount)
			
			if FlooredBeamCount > 0 then
				local Rays = GenerateRays(FlooredBeamCount)
				for i=1, #Rays do
					CreateRain(Rays[i])
				end
			end
			
			BeamsLeft = BeamCount - FlooredBeamCount
		end
		
		if Module.Settings.SplashParticles and Module.Settings.SplashIntensity > 0 then
			local SplashCount = SplashesLeft + Module.Settings.SplashIntensity * deltaTime
			local FlooredSplashCount = MathFloor_(SplashCount)
			
			if FlooredSplashCount > 0 then
				local SplashRays = Module.Settings.SplashParticles and GenerateRays(FlooredSplashCount) or {}
				if Module.Settings.SplashParticles then
					for i=1, #SplashRays do
						CreateSplash(SplashRays[i])
					end
				end
			end
			SplashesLeft = SplashCount - FlooredSplashCount
		end
		
		debug.profileend()
	end)
end

--// ===================== LIFECYCLE =====================

function Module:Start()
	if Module.Running then return end
	if not TopAttachmentTemplates[Module.Settings.Weather] then
		UpdateWeather(Module.Settings.Weather)
	end
	UpdateMaxAttachments()
	UpdateIgnoranceFolder()
	UpdateMaxSplashAttachments()
	UpdateSoundGridModels()
	Module.Running = true
	RunToken += 1
	MainLoop(RunToken)
	Module.StateUpdated:Fire(true)
end
Module.Enable = Module.Start

function Module:Stop()
	if not Module.Running then return end
	Module.Running = false
	if CORE_CONNECTION then
		CORE_CONNECTION:Disconnect()
	end
	CleanupAttachments()
	StopSound()
	Module.StateUpdated:Fire(false)
end
Module.Disable = Module.Stop

--// ===================== Module.Settings =====================

function Module:SetDirection(direction: Vector3?)
	if not direction then direction = DEFAULT_SETTINGS.Direction end
	if direction == Module.Settings.Direction then return end
	CheckType(direction, "Vector3", "SetDirection")
	
	if direction and direction.Magnitude == 0 then
		warn("SetDirection: Direction cannot have a magnitude of 0. Changing to (0,-1,0).")
		direction = DEFAULT_SETTINGS.Direction
	end
	Module.Settings.Direction = direction
	
	Module.SettingUpdated:Fire("Direction", direction)
end

function Module:SetRaycastRadius(radius: number?)
	if not radius then radius = DEFAULT_SETTINGS.RaycastRadius end
	if radius == Module.Settings.RaycastRadius then return end
	CheckType(radius, "number", "SetRaycastRadius")
	
	if radius <= 0 then
		warn("SetRaycastRadius: RaycastRadius cannot be negative. Clamping to 0.")
		radius = 0
	end
	Module.Settings.RaycastRadius = radius
	
	Module.SettingUpdated:Fire("RaycastRadius", radius)
end

function Module:SetScale(scale: number?)
	if not scale then scale = DEFAULT_SETTINGS.Scale end
	if scale == Module.Settings.Scale then return end
	CheckType(scale, "number", "SetScale")
	
	if scale <= 0 then
		warn("SetScale: Scale cannot be zero or negative. Clamping to 0.01.")
		scale = 0.01
	end
	Module.Settings.Scale = scale
	UpdateScale()
	
	Module.SettingUpdated:Fire("Scale", scale)
end
Module.SetSize = Module.SetScale

function Module:SetSpeed(speed: number?)
	if not speed then speed = DEFAULT_SETTINGS.Speed end
	if speed == Module.Settings.Speed then return end
	CheckType(speed, "number", "SetSpeed")
	
	if speed <= 0 then
		warn("SetSpeed: Speed cannot be zero negative. Clamping to 0.01.")
		speed = 0.01
	end
	
	Module.Settings.Speed = speed
	UpdateSpeed()
	UpdateMaxAttachments()
	UpdateMaxSplashAttachments()
	
	Module.SettingUpdated:Fire("Speed", speed)
end

function Module:SetColor(color: Color3?)
	if not color then color = DEFAULT_SETTINGS.Color end
	if color == Module.Settings.Color then return end
	CheckType(color, "Color3", "SetColor")
	
	Module.Settings.Color = color
	UpdateColor()
	
	Module.SettingUpdated:Fire("Color", color)
end

function Module:SetBrightness(value: number?)
	if not value then value = DEFAULT_SETTINGS.Brightness end
	if Module.Settings.Brightness == value then return end -- no need to update
	CheckType(value, "number", "SetBrightness")

	if value < 0 then
		warn("SetBrightness: Brightness cannot be negative. Clamping to 0.")
		value = 0
	end

	Module.Settings.Brightness = value
	UpdateBrightness()
	
	Module.SettingUpdated:Fire("Brightness", value)
end

function Module:SetTransparency(opacity: number?)
	if not opacity then opacity = DEFAULT_SETTINGS.Transparency end
	if opacity == Module.Settings.Transparency then return end -- no need to update
	CheckType(opacity, "number", "SetTransparency")
	
	if opacity < 0 then
		warn("SetTransparency: Transparency cannot be negative. Clamping to 0.")
		opacity = 0
	end
	if opacity > 1 then
		warn("SetTransparency: Transparency cannot be above 1. Clamping to 1.")
		opacity = 1
	end

	Module.Settings.Transparency = opacity
	UpdateTransparency()
	
	Module.SettingUpdated:Fire("Transparency", opacity)
end

function Module:SetLightEmission(emission: number?)
	if not emission then emission = DEFAULT_SETTINGS.LightEmission end
	if Module.Settings.LightEmission == emission then return end -- no need to update
	CheckType(emission, "number", "SetLightEmission")

	Module.Settings.LightEmission = emission
	UpdateLightEmission()
	
	Module.SettingUpdated:Fire("LightEmission", emission)
end

function Module:SetLightInfluence(influence: number?)
	if not influence then influence = DEFAULT_SETTINGS.LightInfluence end
	if Module.Settings.LightInfluence == influence then return end -- no need to update
	CheckType(influence, "number", "SetLightInfluence")
	
	Module.Settings.LightInfluence = influence
	UpdateLightInfluence()
	
	Module.SettingUpdated:Fire("LightInfluence", influence)
end

function Module:SetIntensity(intensity: number?)
	if not intensity then intensity = DEFAULT_SETTINGS.Intensity end
	if Module.Settings.Intensity == intensity then return end -- no need to update
	CheckType(intensity, "number", "SetIntensity")
	
	intensity = MathRound_(intensity) -- align floats
	if intensity < 0 then
		warn("SetIntensity: Intensity cannot be negative. Clamping to 0.")
		intensity = 0
	end
	
	Module.Settings.Intensity = intensity
	UpdateMaxAttachments()
	
	Module.SettingUpdated:Fire("Intensity", intensity)
end

function Module:SetSplashIntensity(intensity: number?)
	if not intensity then intensity = DEFAULT_SETTINGS.SplashIntensity end
	if Module.Settings.SplashIntensity == intensity then return end -- no need to update
	CheckType(intensity, "number", "SetSplashIntensity")

	intensity = MathRound_(intensity) -- align floats
	if intensity < 0 then
		warn("SetSplashIntensity: Intensity cannot be negative. Clamping to 0.")
		intensity = 0
	end

	Module.Settings.SplashIntensity = intensity
	UpdateMaxSplashAttachments()
	
	Module.SettingUpdated:Fire("SplashIntensity", intensity)
end

function Module:SetIgnorePartsAboveTransparency(transparency: number?)
	if not transparency then transparency = DEFAULT_SETTINGS.IgnorePartsAboveTransparency end
	if Module.Settings.IgnorePartsAboveTransparency == transparency then return end -- no need to update
	CheckType(transparency, "number", "SetIgnorePartsAboveTransparency")
	
	if transparency < 0 then
		warn("SetIgnorePartsAboveTransparency: Transparency cannot be negative. Clamping to 0.")
		transparency = 0
	end
	
	Module.Settings.IgnorePartsAboveTransparency = transparency
	
	-- Refresh instances
	local NewIgnoreInstances = {}
	for _,v in IgnoreInstances do
		if v:IsA("BasePart") and v.Transparency < transparency then continue end
		table.insert(NewIgnoreInstances, v)
	end
	IgnoreInstances = NewIgnoreInstances
	
	Module.SettingUpdated:Fire("IgnorePartsAboveTransparency", transparency)
end

function Module:SetIgnorePartsWithTag(tag: string?)
	if not tag then tag = DEFAULT_SETTINGS.IgnorePartsWithTag end
	if Module.Settings.IgnorePartsWithTag == tag then return end -- no need to update
	CheckType(tag, "string", "SetIgnorePartsWithTag")
	
	Module.Settings.IgnorePartsWithTag = tag
	
	-- Refresh instances
	local NewIgnoreInstances = {}
	for _,v in IgnoreInstances do
		if not v:HasTag(tag) then continue end
		table.insert(NewIgnoreInstances, v)
	end
	IgnoreInstances = NewIgnoreInstances
	
	Module.SettingUpdated:Fire("IgnorePartsWithTag", tag)
end

function Module:SetRandomness(randomness: number?)
	if not randomness then randomness = DEFAULT_SETTINGS.Randomness end
	if Module.Settings.Randomness == randomness then return end -- no need to update
	CheckType(randomness, "number", "SetRandomness")
	
	if randomness < 0 then
		warn("SetRandomness: Randomness cannot be negative. Clamping to 0.")
		randomness = 0
	end
	
	Module.Settings.Randomness = randomness
	
	Module.SettingUpdated:Fire("Randomness", randomness)
end

function Module:SetFadeInTime(duration: number?)
	if not duration then duration = DEFAULT_SETTINGS.FadeInTime end
	if Module.Settings.FadeInTime == duration then return end -- no need to update
	CheckType(duration, "number", "SetFadeInTime")
	
	if duration < 0 then
		warn("SetFadeInTime: FadeInTime cannot be negative. Clamping to 0.")
		duration = 0
	end
	Module.Settings.FadeInTime = duration
	UpdateMaxAttachments()
	
	Module.SettingUpdated:Fire("FadeInTime", duration)
end

function Module:SetFadeOutTime(duration: number?)
	if not duration then duration = DEFAULT_SETTINGS.FadeOutTime end
	if Module.Settings.FadeOutTime == duration then return end -- no need to update
	CheckType(duration, "number", "SetFadeOutTime")
	
	if duration < 0 then
		warn("SetFadeOutTime: FadeOutTime cannot be negative. Clamping to 0")
		duration = 0
	end
	Module.Settings.FadeOutTime = duration
	UpdateMaxAttachments()
	
	Module.SettingUpdated:Fire("FadeOutTime", duration)
end

function Module:SetSoundVolume(volume: number?)
	if not volume then volume = DEFAULT_SETTINGS.SoundVolume end
	if Module.Settings.SoundVolume == volume then return end -- no need to update
	CheckType(volume, "number", "SetSoundVolume")
	
	if volume < 0 then
		warn("SetSoundVolume: SoundVolume must be positive. Clamping to 0.")
		volume = 0
	end
	Module.Settings.SoundVolume = volume
	if Module.Running then
		if (not Module.Settings.DynamicSound or Module.Settings.DynamicSoundRadius <= 0) then
			ApplyStaticSound()
		else
			UpdateSound(true)
		end
	end
	
	Module.SettingUpdated:Fire("SoundVolume", volume)
end

function Module:SetWindInfluence(influence: number?)
	if not influence then influence = DEFAULT_SETTINGS.WindInfluence end
	if Module.Settings.WindInfluence == influence then return end -- no need to update
	CheckType(influence, "number", "SetWindInfluence")
	
	if influence < 0 then
		warn("SetWindInfluence: WindInfluence cannot be negative. Clamping to 0.")
		influence = 0
	end
	Module.Settings.WindInfluence = influence
	
	Module.SettingUpdated:Fire("WindInfluence", influence)
end

function Module:SetMistParticles(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.MistParticles end
	if Module.Settings.MistParticles == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetMistParticles")
	
	Module.Settings.MistParticles = enabled
	
	Module.SettingUpdated:Fire("MistParticles", enabled)
end

function Module:SetSplashParticles(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.SplashParticles end
	if Module.Settings.SplashParticles == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetSplashParticles")
	
	Module.Settings.SplashParticles = enabled
	
	Module.SettingUpdated:Fire("SplashParticles", enabled)
end

function Module:SetSplashThreshold(threshold: number?)
	if not threshold then threshold = DEFAULT_SETTINGS.SplashThreshold end
	if Module.Settings.SplashThreshold == threshold then return end -- no need to update

	CheckType(threshold, "number", "SetSplashThreshold")
	if threshold < 0 then
		warn("SetSplashThreshold: SplashThreshold cannot be negative. Clamping to 0.")
		threshold = 0
	end
	if threshold > 1 then
		warn("SetSplashThreshold: SplashThreshold cannot be above 1. Clamping to 1.")
		threshold = 1
	end
	Module.Settings.SplashThreshold = threshold
	
	Module.SettingUpdated:Fire("SplashThreshold", threshold)
end

function Module:SetBeamEffect(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.BeamEffect end
	if Module.Settings.BeamEffect == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetBeamEffect")
	
	Module.Settings.BeamEffect = enabled
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			pair[2].Beam.Enabled = enabled
		end
	end
	
	Module.SettingUpdated:Fire("BeamEffect", enabled)
end

function Module:SetSnowLayers(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.SnowLayers end
	if Module.Settings.SnowLayers == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetSnowLayers")
	
	Module.Settings.SnowLayers = enabled

	if not Module.Settings.SnowLayers then
		for _, v in SnowifiedParts do
			v[2]:RemoveTag("__HAS_SNOW_LAYER")
			local Tween = TweenService:Create(v[1], TweenInfo.new(2), {Transparency = 1}); Tween:Play()
			Tween.Completed:Once(function()
				v[1]:Destroy()
			end)
		end
	end

	Module.SettingUpdated:Fire("SnowLayers", enabled)
end

function Module:SetIgnoreSnowTag(tag: string?)
	if not tag then tag = DEFAULT_SETTINGS.IgnoreSnowTag return end
	if Module.Settings.IgnoreSnowTag == tag then return end -- no need to update
	CheckType(tag, "string", "SetIgnoreSnowTag")
	
	Module.Settings.IgnoreSnowTag = tag
	
	Module.SettingUpdated:Fire("IgnoreSnowTag", tag)
end

function Module:SetPartLockedSplash(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.PartLockedSplash end
	if Module.Settings.PartLockedSplash == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetPartLockedSplash")
	
	Module.Settings.PartLockedSplash = enabled

	UpdateMaxSplashAttachments()
	if not enabled then
		local total = 0
		for weather, attachments in SplashAttachments do
			for _, v in attachments do
				total += 1
				v:Destroy()
			end
		end
		Module.AttachmentCounter.Value -= total
		SplashAttachments = {}
	end

	Module.SettingUpdated:Fire("PartLockedSplash", enabled)
end	

function Module:SetSoundId(id: string?)
	if not id then id = DEFAULT_SETTINGS.SoundId end
	if Module.Settings.SoundId == id then return end -- no need to update
	CheckType(id, "string", "SetSoundAssetId")

	local AmbienceSound = GetSound()
	Module.Settings.SoundId = id
	AmbienceSound:Stop()
	AmbienceSound.SoundId = id

	if Module.Running then
		PlaySound()
	end
	
	Module.SettingUpdated:Fire("SoundId", id)
end

function Module:SetBeamTextureId(id: string?)
	if not id then id = DEFAULT_SETTINGS.BeamTextureId end
	if Module.Settings.BeamTextureId == id then return end -- no need to update
	CheckType(id, "string", "SetBeamTextureId")
	
	Module.Settings.BeamTextureId = id

	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			pair[2].Beam.Texture = id
		end
	end
	
	Module.SettingUpdated:Fire("BeamTextureId", id)
end

function Module:SetMistTextureId(id: string?)
	if not id then id = DEFAULT_SETTINGS.MistTextureId end
	if Module.Settings.MistTextureId == id then return end -- no need to update
	CheckType(id, "string", "SetMistTextureId")
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			pair[1].Mist.Texture = id
		end
	end
	Module.Settings.MistTextureId = id
	
	Module.SettingUpdated:Fire("MistTextureId", id)
end

function Module:SetSplashTextureId(id: string?)
	if not id then id = DEFAULT_SETTINGS.SplashTextureId end
	if Module.Settings.SplashTextureId == id then return end -- no need to update
	CheckType(id, "string", "SetSplashTextureId")
	
	if TotalAttachmentPairs[Module.Settings.Weather] then
		for _, pair in TotalAttachmentPairs[Module.Settings.Weather] do
			pair[2].Splash.Texture = id
		end
	end
	if SplashAttachments[Module.Settings.Weather] then
		for _, attachment in SplashAttachments[Module.Settings.Weather] do
			attachment.Splash.Texture = id
		end
	end
	Module.Settings.SplashTextureId = id
	
	Module.SettingUpdated:Fire("SplashTextureId", id)	
end

function Module:SetRaycastHeight(height: number?)
	if not height then height = DEFAULT_SETTINGS.RaycastHeight end
	if Module.Settings.RaycastHeight == height then return end -- no need to update
	CheckType(height, "number", "SetRaycastHeight")
	
	if height < 0 then
		warn("SetRaycastHeight: RaycastHeight cannot be negative. Clamping to 0.")
		height = 0
	end
	Module.Settings.RaycastHeight = height
	
	Module.SettingUpdated:Fire("RaycastHeight", height)
end

function Module:SetVisualHeight(height: number?)
	if not height then height = DEFAULT_SETTINGS.VisualHeight end
	if Module.Settings.VisualHeight == height then return end -- no need to update
	CheckType(height, "number", "SetVisualHeight")
	
	if height < 0 then
		warn("SetVisualHeight: VisualHeight cannot be negative. Clamping to 0.")
		height = 0
	end
	Module.Settings.VisualHeight = height
	UpdateVisualHeight() -- Recompute speed for beam and Mist to match new height
	
	Module.SettingUpdated:Fire("VisualHeight", height)
end

function Module:SetBeamDuration(duration: number?)
	if not duration then duration = DEFAULT_SETTINGS.BeamDuration end
	if Module.Settings.BeamDuration == duration then return end -- no need to update
	CheckType(duration, "number", "SetBeamDuration")
	
	if duration < 0 then
		warn("SetBeamDuration: BeamDuration cannot be negative. Clamping to 0.")
		duration = 0
	end
	Module.Settings.BeamDuration = duration
	UpdateMaxAttachments()
	
	Module.SettingUpdated:Fire("BeamDuration", duration)
end

function Module:SetDynamicSoundRadius(radius: number?)
	if not radius then radius = DEFAULT_SETTINGS.DynamicSoundRadius end
	if Module.Settings.DynamicSoundRadius == radius then return end -- no need to update
	CheckType(radius, "number", "SetDynamicSoundRadius")
	
	if radius < 0 then
		warn("SetDynamicSoundRadius: DynamicSoundRadius cannot be negative. Clamping to 0.")
		radius = 0
	end
	Module.Settings.DynamicSoundRadius = radius
	RecomputeSoundScanGrid(Module.Settings.SoundGrid)
	if radius == 0 and Module.Settings.DynamicSound and Module.Running then
		-- Skip volume calculations entirely; fall back to a static volume.
		ApplyStaticSound()
	end
	
	Module.SettingUpdated:Fire("DynamicSoundRadius", radius)
end

function Module:SetSoundGroup(group: Instance?)
	if not group then group = DEFAULT_SETTINGS.SoundGroup end
	if Module.Settings.SoundGroup == group then return end -- no need to update

	if group and not group:IsA("SoundGroup") then
		error("SetSoundGroup expects a SoundGroup instance.", 2)
	end
	
	local AmbienceSound = GetSound()
	Module.Settings.SoundGroup = group
	AmbienceSound.SoundGroup = group
	
	Module.SettingUpdated:Fire("SoundGroup", group)
end

function Module:SetDynamicSound(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.DynamicSound end
	if Module.Settings.DynamicSound == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetDynamicSound")
	
	Module.Settings.DynamicSound = enabled
	if not enabled and Module.Running then
		ApplyStaticSound()
	end
	
	Module.SettingUpdated:Fire("DynamicSound", enabled)
end

function Module:SetSoundParent(parent: Instance?)
	if Module.Settings.SoundParent == parent then return end -- no need to update
	if parent then CheckType(parent, "Instance", "SetSoundParent") end

	Module.Settings.SoundParent = parent
	
	Module.SettingUpdated:Fire("SoundParent", parent)
end

function Module:SetSoundGrid(template: string?)
	if not template then template = DEFAULT_SETTINGS.SoundGrid end
	if Module.Settings.SoundGrid == template then return end -- no need to update
	if not SoundGrids[template] then
		warn("Invalid SoundGrid: '" .. template.."'. Using default: '".. DEFAULT_SETTINGS.SoundGrid.."'")
		template = DEFAULT_SETTINGS.SoundGrid
	end
	CheckType(template, "string", "SetSoundGrid")
	
	Module.Settings.SoundGrid = template
	for _, part in SoundGridParts do
		part:Destroy()
	end
	RecomputeSoundScanGrid(template)
	
	Module.SettingUpdated:Fire("SoundGrid", template)
end

function Module:SetVisualizeSoundGrid(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.VisualizeSoundGrid end
	if Module.Settings.VisualizeSoundGrid == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetVisualizeSoundGrid")
	
	Module.Settings.VisualizeSoundGrid = enabled
	if not enabled then
		for _, part in SoundGridParts do
			part:Destroy()
		end
	end
	
	Module.SettingUpdated:Fire("VisualizeSoundGrid", enabled)
end

-- Extra instances to exclude from rain/sound raycasts
function Module:SetExcludeInstances(instances: {Instance}?)
	if not instances then instances = DEFAULT_SETTINGS.ExcludeInstances end
	CheckType(instances, "table", "SetExcludeInstances")
	
	Module.Settings.ExcludeInstances = instances
	UpdateRaycastParams()
	
	Module.SettingUpdated:Fire("ExcludeInstances", instances)
end

function Module:SetExtraMistParticles(count: number?)
	if not count then count = DEFAULT_SETTINGS.ExtraMistParticles end
	if Module.Settings.ExtraMistParticles == count then return end -- no need to update

	CheckType(count, "number", "SetExtraMistParticles")
	Module.Settings.ExtraMistParticles = count
	UpdateExtraMistParticles()
	
	Module.SettingUpdated:Fire("ExtraMistParticles", count)
end

function Module:SetSphereCast(enabled: boolean?)
	if enabled == nil then enabled = DEFAULT_SETTINGS.SphereCast end
	if Module.Settings.SphereCast == enabled then return end -- no need to update
	CheckType(enabled, "boolean", "SetSphereCast")

	Module.Settings.SphereCast = enabled

	Module.SettingUpdated:Fire("SphereCast", enabled)
end

function Module:SetSphereCastRadius(radius: number?)
	if not radius then radius = DEFAULT_SETTINGS.SphereCastRadius end
	if Module.Settings.SphereCastRadius == radius then return end -- no need to update
	CheckType(radius, "number", "SetSphereCastRadius")

	if radius < 0 then
		warn("SetSphereCastRadius: SphereCastRadius cannot be negative. Clamping to 0.")
		radius = 0
	end
	if radius > 256 then
		warn("SetSphereCastRadius: SphereCastRadius cannot be greater than 256. Clamping to 256.")
	end
	
	Module.Settings.SphereCastRadius = radius

	Module.SettingUpdated:Fire("SphereCastRadius", radius)
end
function Module:SetWeather(weather: string)
	if not weather then return end
	if weather == Module.Settings.Weather then return end
	CheckType(weather, "string", "SetWeather")

	UpdateWeather(weather)

	Module.SettingUpdated:Fire("Weather", weather)
end

function Module:Set(setting: string, value: any)
	local GetSettingMethod = Module["Set"..setting]
	if GetSettingMethod then
		GetSettingMethod(value)
	else
		warn("Invalid setting: '"..setting.."'")
	end
end

function Module:Cleanup() -- Deletes all instances created by the module
	RunToken += 1 -- Stops cleanup
	Module:Stop()
	StopSound()
	
	-- Remove sound grid visualization parts
	for _, part in SoundGridParts do
		part:Destroy()
	end
	for _, model in SoundGridPartModels do
		model:Destroy()
	end

	-- Remove all attachments
	for weather, getPairs in TotalAttachmentPairs do
		for _, attachment in getPairs do
			attachment[1]:Destroy()
			attachment[2]:Destroy()
			for _, extra in attachment[3] do
				extra:Destroy()
			end
		end
	end
	for weather, attachments in SplashAttachments do
		for _, attachment in attachments do
			attachment:Destroy()
		end
	end

	Module.AttachmentCounter.Value = 0

	-- Remove sounds
	for _, v in BackgroundAmbienceSounds do
		v:Destroy()
	end

	for _, v in SnowifiedParts do
		v[1]:Destroy()
		v[2]:RemoveTag("__HAS_SNOW_LAYER")
	end

	ActiveQueue = {}
	SnowifiedParts = {}
	BackgroundAmbienceSounds = {}
	SplashAttachments = {}
	TotalAttachmentPairs = {}
	
end

return Module