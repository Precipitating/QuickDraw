-- Camera Shake Presets
-- Stephen Leitnick
-- February 26, 2018
-- Updated with custom game presets

--[[
    CameraShakePresets.Bump
    CameraShakePresets.Explosion
    CameraShakePresets.Earthquake
    CameraShakePresets.BadTrip
    CameraShakePresets.HandheldCamera
    CameraShakePresets.Vibration
    CameraShakePresets.RoughDriving
    
    -- New Presets:
    CameraShakePresets.Heartbeat
    CameraShakePresets.GunRecoil
    CameraShakePresets.Sprinting
    CameraShakePresets.SnipingBreath
    CameraShakePresets.HeavyThud
    CameraShakePresets.Flashbang
    CameraShakePresets.AircraftTurbulence
    CameraShakePresets.BearTrapInjury
	 CameraShakePresets.CannonballHit
--]]

local CameraShakeInstance = require(script.Parent.CameraShakeInstance)

local CameraShakePresets = {

	-- Meant to resemble a strong, shoulder barge
	Bump = function()
		local c = CameraShakeInstance.new(4, 7, 0.03, 0.9)
		c.PositionInfluence = Vector3.new(0.25, 0.2, 0.3)
		c.RotationInfluence = Vector3.new(2, 1.5, 3)
		return c
	end,

	-- An intense and rough shake.
	-- Should happen once.
	Explosion = function()
		local c = CameraShakeInstance.new(5, 10, 0, 1.5)
		c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
		c.RotationInfluence = Vector3.new(4, 1, 1)
		return c
	end,

	-- A continuous, rough shake
	-- Sustained.
	Earthquake = function()
		local c = CameraShakeInstance.new(0.6, 3.5, 2, 10)
		c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
		c.RotationInfluence = Vector3.new(1, 1, 4)
		return c
	end,

	-- A bizarre shake with a very high magnitude and low roughness.
	-- Sustained.
	BadTrip = function()
		local c = CameraShakeInstance.new(10, 0.15, 5, 10)
		c.PositionInfluence = Vector3.new(0, 0, 0.15)
		c.RotationInfluence = Vector3.new(2, 1, 4)
		return c
	end,

	-- A subtle, slow shake.
	-- Sustained.
	HandheldCamera = function()
		local c = CameraShakeInstance.new(1, 0.25, 5, 10)
		c.PositionInfluence = Vector3.new(0, 0, 0)
		c.RotationInfluence = Vector3.new(1, 0.5, 0.5)
		return c
	end,

	-- A very rough, yet low magnitude shake.
	-- Sustained.
	Vibration = function()
		local c = CameraShakeInstance.new(0.4, 20, 2, 2)
		c.PositionInfluence = Vector3.new(0, 0.15, 0)
		c.RotationInfluence = Vector3.new(1.25, 0, 4)
		return c
	end,

	-- A slightly rough, medium magnitude shake.
	-- Sustained.
	RoughDriving = function()
		local c = CameraShakeInstance.new(1, 2, 1, 1)
		c.PositionInfluence = Vector3.new(0, 0, 0)
		c.RotationInfluence = Vector3.new(1, 1, 1)
		return c
	end,

	----------------------------------------------------------------------------
	-- NEW EXPANDED PRESETS
	----------------------------------------------------------------------------

	-- Perfect for low-health UI indicators or scary horror game moments.
	-- High roughness but extremely low duration creates a pulse feel. One-shot.
	Heartbeat = function()
		local c = CameraShakeInstance.new(3.5, 12, 0.05, 0.3)
		c.PositionInfluence = Vector3.new(0.05, 0.05, 0.05)
		c.RotationInfluence = Vector3.new(0.8, 0.2, 0.2)
		return c
	end,

	-- Sharp vertical and backwards kick for guns.
	-- Snaps up rapidly, settles smoothly. One-shot.
	GunRecoil = function()
		local c = CameraShakeInstance.new(7, 22, 0, 0.3)
		c.PositionInfluence = Vector3.new(0, 0, 0.35)
		c.RotationInfluence = Vector3.new(4.5, 0.7, 0.7)
		return c
	end,

	-- Rhythmic bobbing for first-person sprinting mechanics.
	-- Sustained (Looping). Clear it when the player stops running.
	Sprinting = function()
		local c = CameraShakeInstance.new(1.2, 7, 0.5, 0.5)
		c.PositionInfluence = Vector3.new(0.1, 0.2, 0) -- High vertical bobbing
		c.RotationInfluence = Vector3.new(1, 0.5, 1.5) -- Side-to-side shoulder sway
		return c
	end,

	-- Micro sway when aiming down sight with a sniper rifle.
	-- Sustained. Smooth, incredibly low frequency.
	SnipingBreath = function()
		local c = CameraShakeInstance.new(0.2, 0.4, 1, 1)
		c.PositionInfluence = Vector3.new(0, 0, 0)
		c.RotationInfluence = Vector3.new(0.3, 0.3, 0.1)
		return c
	end,

	-- For boss footsteps, a heavy crate landing, or nearby ground impacts.
	-- Sharp initial drop down, fast falloff. One-shot.
	HeavyThud = function()
		local c = CameraShakeInstance.new(4, 8, 0.02, 0.6)
		c.PositionInfluence = Vector3.new(0, 0.4, 0) -- Drops down vertically on hit
		c.RotationInfluence = Vector3.new(1.5, 0, 0.5)
		return c
	end,

	-- Disorienting slow-roll shake. Pair this with a white screen effect.
	-- One-shot. High magnitude but incredibly smooth, lingering for a long time.
	Flashbang = function()
		local c = CameraShakeInstance.new(8, 0.6, 0.1, 5.0)
		c.PositionInfluence = Vector3.new(0.1, 0.1, 0.1)
		c.RotationInfluence = Vector3.new(2, 3, 5) -- Dizziness rotation twist
		return c
	end,

	-- For planes, helicopters, or fast elevators.
	-- Sustained. Low-frequency bumping mixed with high yaw rotation.
	AircraftTurbulence = function()
		local c = CameraShakeInstance.new(1.5, 4.5, 2, 2)
		c.PositionInfluence = Vector3.new(0.2, 0.3, 0.2)
		c.RotationInfluence = Vector3.new(1, 2, 1.5)
		return c
	end,

	BearTrapInjury = function()
		local c = CameraShakeInstance.new(6, 15, 0, 2.0)
		c.PositionInfluence = Vector3.new(0.1, 0.3, 0.05) -- sharp vertical jolt (leg buckling)
		c.RotationInfluence = Vector3.new(2.5, 0.5, 3) -- pitch dip + roll stagger
		return c
	end,
	-- Devastating full-body impact from cannon fire. Max intensity one-shot.
	CannonballHit = function()
		local c = CameraShakeInstance.new(9, 20, 0, 2.5)
		c.PositionInfluence = Vector3.new(0.4, 0.35, 0.5) -- huge shove in all axes
		c.RotationInfluence = Vector3.new(3, 4, 5) -- violent tumble/spin
		return c
	end,
}

return setmetatable({}, {
	__index = function(t, i)
		local f = CameraShakePresets[i]
		if type(f) == "function" then
			return f()
		end
		error('No preset found with index "' .. i .. '"')
	end,
})
