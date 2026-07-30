local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerScreenEffects = {}

function ServerScreenEffects:ApplyOneShotEffect(player: Player, effectName: string)
	if not player then
		return
	end

	local buf, err = Sera.Serialize(SeraSchemas.ScreenEffectsSchema, {
		EffectName = effectName,
	})

	if err then
		error(err)
	end
	self.networker:fire(player, "ApplyOneShotEffect", buf)
end
function ServerScreenEffects:StartSustainEffect(player: Player, effectName: string)
	local buf, err = Sera.Serialize(SeraSchemas.ScreenEffectsSchema, {
		EffectName = effectName,
	})
	if err then
		error(err)
	end
	self.networker:fire(player, "StartSustainEffect", buf)
end
function ServerScreenEffects:StopAllSustainEffects(player: Player)
	self.networker:fire(player, "StopAllSustainEffects")
end

ServerScreenEffects.networker = Networker.new("ScreenEffectsNetwork", ServerScreenEffects)

return ServerScreenEffects
