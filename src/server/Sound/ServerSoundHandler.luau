local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerSoundHandler = {}
local SoundLimiter = RateLimiter.new(10)
function ServerSoundHandler:Play3DOneShotToOthers(
	playerToExclude: Player?,
	soundName: string,
	position: Vector3,
	config
)
	if not SoundLimiter:TryConsume() then
		return
	end

	local closePlayers = Utility.GetClosePlayers(position, config and config.MaxDistance or 300)
	local payload = {
		SoundName = soundName,
		Position = position or Vector3.zero,
	}

	if config then
		for key, val in config do
			if config[key] ~= nil then
				payload[key] = config[key]
			end
		end
	end

	local buf, err = Sera.DeltaSerialize(SeraSchemas.Play3DOneShotSchema, payload)
	if not buf then
		warn(err)
		return
	end

	for _, player in closePlayers do
		if player == playerToExclude then
			continue
		end
		self.networker:fire(player, "Play3DOneShotToOthers", buf)
	end
end

function ServerSoundHandler:Play3DNPCVoiceline(
	playerToExclude: Player?,
	soundName: string,
	NPCSoundInstance: Sound?,
	config
)
	if not SoundLimiter:TryConsume() then
		return
	end

	local payload = {
		SoundName = soundName,
	}

	if config then
		for key, val in config do
			if config[key] ~= nil then
				payload[key] = config[key]
			end
		end
	end

	local buf, err = Sera.DeltaSerialize(SeraSchemas.Play3DNPCVoicelineSchema, payload)
	if not buf then
		warn(err)
		return
	end

	if playerToExclude then
		self.networker:fireAllExcept(playerToExclude, "Play3DNPCVoiceline", buf, NPCSoundInstance)
	else
		self.networker:fireAll("Play3DNPCVoiceline", buf, NPCSoundInstance)
	end
end

function ServerSoundHandler:PlaySoundTo(player: Player?, soundName: string, options)
	if not SoundLimiter:TryConsume() then
		return
	end
	if not player then
		self.networker:fireAll("PlayOneShot", soundName, options)
	else
		self.networker:fire(player, "PlayOneShot", soundName, options)
	end
end

ServerSoundHandler.networker = Networker.new("SoundNetwork", ServerSoundHandler)
return ServerSoundHandler
