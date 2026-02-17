-- ReplicatedStorage/Modules/SoundManager/SoundManager.lua

local SoundManager = {}

-------------------------------------------------
-- Services
-------------------------------------------------
local SoundService = game:GetService("SoundService")

local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local SoundData = require(script.Parent.SoundData)

-------------------------------------------------
-- Types
-------------------------------------------------

export type SoundConfig = {
	SoundId: string,
	Volume: number?,
	PlaybackSpeed: number?,
	Looped: boolean?,
	Group: string?,
	PoolSize: number?,
}

export type PlayOptions = {
	FadeIn: number?, -- fade-in duration (seconds)
	FadeOut: number?, -- fade-out duration when stopped
	Pitch: number?, -- override playback speed
	Volume: number?, -- override volume
	Parent: Instance?, -- for 3D spatial sounds
	Position: Vector3?, -- attach to a part at position
	MaxDistance: number?, -- RollOffMaxDistance
	MinDistance: number?, -- RollOffMinDistance
	LoopCount: number?, -- play N times then stop (0 = infinite if looped)
	OnEnded: (() -> ())?, -- callback when sound ends
}

-------------------------------------------------
-- Constants
-------------------------------------------------
local DEFAULT_POOL_SIZE = 1
local DEFAULT_FADE_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
local SOUND_FOLDER_NAME = "SoundManagerSounds"

-------------------------------------------------
-- Internal State
-------------------------------------------------
local _initialized = false
local _soundFolder: Folder -- holds all Sound instances
local _soundPools: { [string]: { Sound } } = {} -- pooled Sound objects
local _activeSounds: { [string]: Sound } = {} -- named active sounds (music, ambient, etc.)
local _groupVolumes: { [string]: number } = {}
local _masterVolume: number = 1.0
local _tweens: { [Sound]: Tween } = {} -- active fade tweens
local _connections: { [Sound]: RBXScriptConnection } = {}
local _muted: boolean = false
local _previousVolumes: { [string]: number } = {} -- stored volumes before mute

-------------------------------------------------
-- Private Helpers
-------------------------------------------------

--- Create the container folder for all sounds
local function _createSoundFolder(): Folder
	local folder = Instance.new("Folder")
	folder.Name = SOUND_FOLDER_NAME
	folder.Parent = SoundService
	return folder
end

--- Create a group subfolder
local function _getGroupFolder(group: string): Folder
	local groupFolder = _soundFolder:FindFirstChild(group)
	if not groupFolder then
		groupFolder = Instance.new("Folder")
		groupFolder.Name = group
		groupFolder.Parent = _soundFolder
	end
	return groupFolder
end

--- Calculate final volume considering group + master
local function _calcVolume(baseVolume: number, group: string?): number
	local groupVol = _groupVolumes[group or "SFX"] or 1.0
	return baseVolume * groupVol * _masterVolume
end

--- Build a Sound instance from config
local function _createSoundInstance(name: string, config: SoundConfig): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.SoundId
	sound.Volume = _calcVolume(config.Volume or 1, config.Group)
	sound.PlaybackSpeed = config.PlaybackSpeed or 1
	sound.Looped = config.Looped or false
	sound.RollOffMode = Enum.RollOffMode.Linear

	-- Store metadata as attributes for later use
	sound:SetAttribute("BaseVolume", config.Volume or 1)
	sound:SetAttribute("Group", config.Group or "SFX")
	sound:SetAttribute("SoundName", name)

	local groupFolder = _getGroupFolder(config.Group or "SFX")
	sound.Parent = groupFolder

	return sound
end

--- Get an available sound from the pool
local function _getFromPool(name: string): Sound?
	local pool = _soundPools[name]
	if not pool then
		return nil
	end

	for _, sound in pool do
		if not sound.IsPlaying then
			return sound
		end
	end

	-- All sounds in pool are playing; return nil (pool exhausted)
	return nil
end

--- Cancel any active tween on a sound
local function _cancelTween(sound: Sound)
	local tween = _tweens[sound]
	if tween then
		tween:Cancel()
		_tweens[sound] = nil
	end
end

--- Disconnect ended connection
local function _disconnectEnded(sound: Sound)
	local conn = _connections[sound]
	if conn then
		conn:Disconnect()
		_connections[sound] = nil
	end
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Initialize the SoundManager. Call once on client startup.
function SoundManager.Init()
	if _initialized then
		warn("[SoundManager] Already initialized.")
		return
	end

	-- Create container
	_soundFolder = _createSoundFolder()

	-- Set group volumes from defaults
	for group, vol in SoundData.GroupDefaults do
		if group == "Master" then
			_masterVolume = vol
		else
			_groupVolumes[group] = vol
		end
	end

	-- Pre-create sound pools from SoundData
	local preloadList: { Sound } = {}

	for name, config in SoundData.Sounds do
		local poolSize = config.PoolSize or DEFAULT_POOL_SIZE
		_soundPools[name] = {}

		for i = 1, poolSize do
			local sound = _createSoundInstance(name .. "_" .. i, config)
			table.insert(_soundPools[name], sound)
			table.insert(preloadList, sound)
		end
	end

	-- Preload all sound assets in background
	task.spawn(function()
		ContentProvider:PreloadAsync(preloadList)
		print("[SoundManager] All sounds preloaded.")
	end)

	_initialized = true
	print("[SoundManager] Initialized.")
end

-------------------------------------------------
-- Core Playback
-------------------------------------------------

--- Play a sound by registered name
function SoundManager.Play(name: string, options: PlayOptions?): Sound?
	assert(_initialized, "[SoundManager] Not initialized. Call SoundManager.Init() first.")
	local config = SoundData.Sounds[name]
	assert(config, "[SoundManager] Unknown sound: " .. name)

	local opts: PlayOptions = options or {}
	local sound = _getFromPool(name)

	if not sound then
		-- Pool exhausted — optionally create overflow instance
		warn("[SoundManager] Pool exhausted for: " .. name .. ". Creating overflow instance.")
		sound = _createSoundInstance(name .. "_overflow", config)
		table.insert(_soundPools[name], sound)
	end

	-- Cancel previous tweens
	_cancelTween(sound)
	_disconnectEnded(sound)

	-- Apply overrides
	local baseVol = opts.Volume or config.Volume or 1
	sound:SetAttribute("BaseVolume", baseVol)
	sound.PlaybackSpeed = opts.Pitch or config.PlaybackSpeed or 1

	-- 3D Spatial: Parent to a Part for positional audio
	if opts.Parent then
		sound.Parent = opts.Parent
		sound.RollOffMaxDistance = opts.MaxDistance or 100
		sound.RollOffMinDistance = opts.MinDistance or 10
	end

	-- Ended callback / loop count
	if opts.OnEnded then
		local loopCount = opts.LoopCount or 0
		local playCount = 0

		_connections[sound] = sound.Ended:Connect(function()
			playCount += 1
			if loopCount > 0 and playCount >= loopCount then
				sound:Stop()
				_disconnectEnded(sound)
				opts.OnEnded()
			elseif not sound.Looped then
				_disconnectEnded(sound)
				opts.OnEnded()
			end
		end)
	end

	-- Fade in
	if opts.FadeIn and opts.FadeIn > 0 then
		sound.Volume = 0
		sound:Play()
		local targetVol = _calcVolume(baseVol, config.Group)
		local tweenInfo = TweenInfo.new(opts.FadeIn, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(sound, tweenInfo, { Volume = targetVol })
		_tweens[sound] = tween
		tween:Play()
	else
		sound.Volume = _calcVolume(baseVol, config.Group)
		sound:Play()
	end

	return sound
end

--- Play a sound and track it by a unique key (useful for music / ambient)
function SoundManager.PlayKeyed(key: string, name: string, options: PlayOptions?): Sound?
	-- Stop any existing sound on this key
	SoundManager.StopKeyed(key, options and options.FadeOut)

	local sound = SoundManager.Play(name, options)
	if sound then
		_activeSounds[key] = sound
	end
	return sound
end

-------------------------------------------------
-- Stop / Pause / Resume
-------------------------------------------------

--- Stop a specific Sound instance
function SoundManager.StopSound(sound: Sound, fadeOut: number?)
	if not sound then
		return
	end
	_cancelTween(sound)

	if fadeOut and fadeOut > 0 then
		local tweenInfo = TweenInfo.new(fadeOut, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(sound, tweenInfo, { Volume = 0 })
		_tweens[sound] = tween
		tween:Play()
		tween.Completed:Connect(function()
			sound:Stop()
			_tweens[sound] = nil
			-- Restore base volume for pool reuse
			local baseVol = sound:GetAttribute("BaseVolume") or 1
			local group = sound:GetAttribute("Group") or "SFX"
			sound.Volume = _calcVolume(baseVol, group)
		end)
	else
		sound:Stop()
	end

	_disconnectEnded(sound)
end

--- Stop a keyed sound (e.g., "Music", "Ambient")
function SoundManager.StopKeyed(key: string, fadeOut: number?)
	local sound = _activeSounds[key]
	if sound then
		SoundManager.StopSound(sound, fadeOut)
		_activeSounds[key] = nil
	end
end

--- Stop all sounds in a group
function SoundManager.StopGroup(group: string, fadeOut: number?)
	for name, pool in _soundPools do
		for _, sound in pool do
			if sound:GetAttribute("Group") == group and sound.IsPlaying then
				SoundManager.StopSound(sound, fadeOut)
			end
		end
	end
end

--- Stop every sound
function SoundManager.StopAll(fadeOut: number?)
	for _, pool in _soundPools do
		for _, sound in pool do
			if sound.IsPlaying then
				SoundManager.StopSound(sound, fadeOut)
			end
		end
	end
	table.clear(_activeSounds)
end

--- Pause a keyed sound
function SoundManager.PauseKeyed(key: string)
	local sound = _activeSounds[key]
	if sound and sound.IsPlaying then
		sound:Pause()
	end
end

--- Resume a keyed sound
function SoundManager.ResumeKeyed(key: string, fadeIn: number?)
	local sound = _activeSounds[key]
	if sound and sound.IsPaused then
		if fadeIn and fadeIn > 0 then
			local targetVol = sound.Volume
			sound.Volume = 0
			sound:Resume()
			local tweenInfo = TweenInfo.new(fadeIn, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(sound, tweenInfo, { Volume = targetVol })
			_tweens[sound] = tween
			tween:Play()
		else
			sound:Resume()
		end
	end
end

-------------------------------------------------
-- Volume Controls
-------------------------------------------------

--- Set master volume (0–1)
function SoundManager.SetMasterVolume(volume: number)
	_masterVolume = math.clamp(volume, 0, 1)
	SoundManager._refreshAllVolumes()
end

--- Get master volume
function SoundManager.GetMasterVolume(): number
	return _masterVolume
end

--- Set a group's volume (0–1)
function SoundManager.SetGroupVolume(group: string, volume: number)
	_groupVolumes[group] = math.clamp(volume, 0, 1)
	SoundManager._refreshAllVolumes()
end

--- Get a group's volume
function SoundManager.GetGroupVolume(group: string): number
	return _groupVolumes[group] or 1.0
end

--- Mute / Unmute all audio
function SoundManager.SetMuted(muted: boolean)
	_muted = muted
	if muted then
		_previousVolumes["Master"] = _masterVolume
		_masterVolume = 0
	else
		_masterVolume = _previousVolumes["Master"] or 1.0
	end
	SoundManager._refreshAllVolumes()
end

function SoundManager.IsMuted(): boolean
	return _muted
end

--- Recalculate volumes on all active pool sounds
function SoundManager._refreshAllVolumes()
	for _, pool in _soundPools do
		for _, sound in pool do
			local baseVol = sound:GetAttribute("BaseVolume") or 1
			local group = sound:GetAttribute("Group") or "SFX"
			sound.Volume = _calcVolume(baseVol, group)
		end
	end
end

-------------------------------------------------
-- Music Helpers (Crossfade)
-------------------------------------------------

--- Crossfade from current music to a new track
function SoundManager.CrossfadeMusic(newSoundName: string, duration: number?)
	local dur = duration or 1.5
	local halfDur = dur / 2

	-- Fade out current music
	local currentMusic = _activeSounds["Music"]
	if currentMusic and currentMusic.IsPlaying then
		SoundManager.StopSound(currentMusic, halfDur)
	end

	-- Fade in new music after half duration
	task.delay(halfDur * 0.5, function()
		SoundManager.PlayKeyed("Music", newSoundName, {
			FadeIn = halfDur,
		})
	end)
end

-------------------------------------------------
-- 3D / Spatial Sound
-------------------------------------------------

--- Play a sound at a world position (attaches to a temporary part)
function SoundManager.PlayAtPosition(name: string, position: Vector3, options: PlayOptions?): Sound?
	local opts: PlayOptions = options or {}

	-- Create an invisible anchored part
	local part = Instance.new("Part")
	part.Name = "SoundEmitter_" .. name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = workspace

	opts.Parent = part

	-- Don't use pool for positional — create a fresh instance
	local config = SoundData.Sounds[name]
	assert(config, "[SoundManager] Unknown sound: " .. name)

	local sound = _createSoundInstance(name .. "_3D", config)
	sound.Parent = part
	sound.RollOffMaxDistance = opts.MaxDistance or 100
	sound.RollOffMinDistance = opts.MinDistance or 10

	local baseVol = opts.Volume or config.Volume or 1
	sound.Volume = _calcVolume(baseVol, config.Group)
	sound.PlaybackSpeed = opts.Pitch or config.PlaybackSpeed or 1

	sound:Play()

	-- Auto-cleanup when done
	sound.Ended:Once(function()
		sound:Destroy()
		part:Destroy()
	end)

	return sound
end

--- Play a sound attached to an existing part/model
function SoundManager.PlayOnInstance(name: string, parent: Instance, options: PlayOptions?): Sound?
	local opts: PlayOptions = options or {}
	opts.Parent = parent
	return SoundManager.Play(name, opts)
end

-------------------------------------------------
-- Utility
-------------------------------------------------

--- Check if a keyed sound is currently playing
function SoundManager.IsPlaying(key: string): boolean
	local sound = _activeSounds[key]
	return sound ~= nil and sound.IsPlaying
end

--- Get the Sound instance for a keyed sound
function SoundManager.GetKeyed(key: string): Sound?
	return _activeSounds[key]
end

--- Register a new sound at runtime (not in SoundData)
function SoundManager.Register(name: string, config: SoundConfig)
	assert(not SoundData.Sounds[name], "[SoundManager] Sound already registered: " .. name)
	SoundData.Sounds[name] = config

	local poolSize = config.PoolSize or DEFAULT_POOL_SIZE
	_soundPools[name] = {}

	for i = 1, poolSize do
		local sound = _createSoundInstance(name .. "_" .. i, config)
		table.insert(_soundPools[name], sound)
	end
end

--- Preload specific sounds by name
function SoundManager.Preload(names: { string })
	local instances: { Sound } = {}
	for _, name in names do
		local pool = _soundPools[name]
		if pool then
			for _, sound in pool do
				table.insert(instances, sound)
			end
		end
	end
	ContentProvider:PreloadAsync(instances)
end

--- Full cleanup — call on player leaving or module teardown
function SoundManager.Destroy()
	SoundManager.StopAll()

	for sound, tween in _tweens do
		tween:Cancel()
	end
	table.clear(_tweens)

	for sound, conn in _connections do
		conn:Disconnect()
	end
	table.clear(_connections)

	if _soundFolder then
		_soundFolder:Destroy()
	end

	table.clear(_soundPools)
	table.clear(_activeSounds)
	_initialized = false

	print("[SoundManager] Destroyed.")
end

return SoundManager
