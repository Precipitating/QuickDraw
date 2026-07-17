local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerScreenEffects = {}

function ServerScreenEffects:ApplyOneShotEffect(player: Player, effectName: string)
	if not player then
		return
	end
	self.networker:fire(player, "ApplyOneShotEffect", effectName)
end
function ServerScreenEffects:StartSustainEffect(player: Player, effectName: string)
	self.networker:fire(player, "StartSustainEffect", effectName)
end
function ServerScreenEffects:StopAllSustainEffects(player: Player)
	self.networker:fire(player, "StopAllSustainEffects")
end

ServerScreenEffects.networker = Networker.new("ScreenEffectsNetwork", ServerScreenEffects)

return ServerScreenEffects
