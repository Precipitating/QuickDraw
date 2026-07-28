local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)

export type PlayOptions = SoundManager.PlayOptions
local ClientSoundHandler = {}
ClientSoundHandler.networker = Networker.new("SoundNetwork", ClientSoundHandler)

function ClientSoundHandler:PlayKeyed(key: string, name: string, options: PlayOptions?)
	SoundManager.PlayKeyed(key, name, options)
end

function ClientSoundHandler:PlayOneShot(name: string, options: PlayOptions?)
	warn(name)
	SoundManager.Play(name, options)
end

function ClientSoundHandler:Play3DOneShotToOthers(soundName: string, position: Vector3, config: PlayOptions?)
	-- client probably doesn't have the object loaded in
	if not position then
		return
	end
	SoundManager.PlayAtPosition(soundName, position, config)
end

function ClientSoundHandler:Play3DNPCVoiceline(soundName: string, soundInstance: Sound, config: PlayOptions?)
	if not soundInstance then
		-- usually because of client not in range
		return
	end
	SoundManager.Play3DNPCVoiceline(soundName, soundInstance, config)
end

return ClientSoundHandler
