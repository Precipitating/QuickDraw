local ServerScriptService = game:GetService("ServerScriptService")
local AwardConstants = require(script.Parent.AwardConstants)
local ServerData = require(ServerScriptService.Server.ServerData)
local AwardHandler = {}

function AwardHandler.AwardNPCKill(killer: Player)
	ServerData.UpdateMoney(killer, AwardConstants.NPC_KILL_AWARD)
	ServerData.UpdateBounty(killer, AwardConstants.NPC_KILL_BOUNTY)
end

function AwardHandler.AwardPlayerKill(killer: Player)
	ServerData.UpdateMoney(killer, AwardConstants.PLAYER_KILL_AWARD)
	ServerData.UpdateBounty(killer, AwardConstants.PLAYER_KILL_BOUNTY)
end
return AwardHandler
