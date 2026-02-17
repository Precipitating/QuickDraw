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

function ClientSoundHandler:Play3DOneShotToOthers(soundName: string, emitterCFrame: CFrame, config: PlayOptions?)
	SoundManager.PlayAtPosition(soundName, emitterCFrame.Position, config)
end

return ClientSoundHandler
