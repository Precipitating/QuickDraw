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
		print("Should hear NPC shooting")
		self.networker:fireAll("Play3DOneShotToOthers", soundName, emitterCFrame, config)
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
