local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ClientDigHandler = {}

local LoopStartConn = nil
local LoopEndConn = nil
local DigSoundLoop = nil

function ClientDigHandler:StartDigging(animName: string, soundName: string)
	local humanoid: Humanoid? = PlayerContext.Humanoid
	if not humanoid then
		warn("Can't dig, missing humanoid ref")
		return
	end

	if LoopStartConn then
		LoopStartConn:Disconnect()
	end
	if LoopEndConn then
		LoopEndConn:Disconnect()
	end

	humanoid.WalkSpeed = 0

	ClientUtility.ToggleControls(false)
	CoreGUIHandler.ToggleBackpackVisibility(false, true)
	local digAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation(animName)
	local loopStartTimePos = digAnim:GetTimeOfKeyframe("LoopBegin")
	LoopEndConn = digAnim:GetMarkerReachedSignal("LoopEnd"):Connect(function()
		digAnim.TimePosition = loopStartTimePos
	end)

	DigSoundLoop = SoundManager.PlayKeyed("SFX", soundName)
end

function ClientDigHandler:StopDigging()
	if DigSoundLoop then
		SoundManager.StopSound(DigSoundLoop)
		DigSoundLoop = nil
	end

	if not PlayerContext.Character then
		return
	end
	local humanoid: Humanoid? = PlayerContext.Humanoid
	if not humanoid then
		return
	end

	if LoopEndConn then
		LoopEndConn:Disconnect()
	end
	humanoid.WalkSpeed = HumanConstants.WALKSPEED
	ClientUtility.ToggleControls(true)
	CoreGUIHandler.ToggleBackpackVisibility(true, false)
end
return ClientDigHandler
