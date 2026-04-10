local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerSoundHandler = {}

function ServerSoundHandler:Play3DOneShotToOthers(
	playerToExclude: Player?,
	soundName: string,
	emitterCFrame: CFrame?,
	config
)
	if playerToExclude then
		self.networker:fireAllExcept(playerToExclude, "Play3DOneShotToOthers", soundName, emitterCFrame, config)
	else
		self.networker:fireAll("Play3DOneShotToOthers", soundName, emitterCFrame, config)
	end
end

function ServerSoundHandler:Play3DNPCVoiceline(
	playerToExclude: Player?,
	soundName: string,
	NPCSoundInstance: Sound?,
	config
)
	if playerToExclude then
		self.networker:fireAllExcept(playerToExclude, "Play3DNPCVoiceline", soundName, NPCSoundInstance, config)
	else
		self.networker:fireAll("Play3DNPCVoiceline", soundName, NPCSoundInstance, config)
	end
end

function ServerSoundHandler:PlaySoundTo(player: Player?, soundName: string, options)
	if not player then
		self.networker:fireAll("PlayOneShot", soundName, options)
	else
		self.networker:fire(player, "PlayOneShot", soundName, options)
	end
end

ServerSoundHandler.networker = Networker.new("SoundNetwork", ServerSoundHandler)
return ServerSoundHandler
