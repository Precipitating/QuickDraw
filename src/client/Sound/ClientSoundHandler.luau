local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local PlayOneShotSchema = SeraSchemas.Play3DOneShotSchema

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

function ClientSoundHandler:Play3DOneShotToOthers(buf)
	local data = Sera.DeltaDeserialize(PlayOneShotSchema, buf)
	local position = data.Position
	local soundName = data.SoundName
	-- client probably doesn't have the object loaded in
	if not position then
		return
	end
	SoundManager.PlayAtPosition(soundName, position, {
		MaxDistance = data.MaxDistance or nil,
		Volume = data.Volume or 1,
		Pitch = data.Pitch or 1,
	})
end

function ClientSoundHandler:Play3DNPCVoiceline(buf, soundInstance: Sound)
	if not soundInstance then
		-- usually because of client not in range
		return
	end

	local data = Sera.DeltaDeserialize(SeraSchemas.Play3DNPCVoicelineSchema, buf)

	local soundName = data.SoundName

	SoundManager.Play3DNPCVoiceline(
		soundName,
		soundInstance,
		{ MaxDistance = data.MaxDistance, Volume = data.Volume or 1, Pitch = data.Pitch or 1 }
	)
end

return ClientSoundHandler
