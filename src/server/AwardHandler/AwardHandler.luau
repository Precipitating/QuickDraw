local ServerScriptService = game:GetService("ServerScriptService")
local AwardConstants = require(script.Parent.AwardConstants)
local ServerData = require(script.Parent.Parent.ServerData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local AwardHandler = {}

function AwardHandler.AwardNPCKill(killer: Player)
	ServerData.UpdateMoney(killer, AwardConstants.NPC_KILL_AWARD)
	ServerData.UpdateBounty(killer, AwardConstants.NPC_KILL_BOUNTY)
end

function AwardHandler.AwardPlayerKill(victim: Player, killer: Player)
	-- award killer victim's bounty if exists
	local victimBounty = ServerData:GetBounty(victim)

	local finalMoneyAward = if victimBounty and victimBounty > 0
		then AwardConstants.PLAYER_KILL_AWARD + victimBounty
		else AwardConstants.PLAYER_KILL_AWARD

	ServerData.UpdateMoney(killer, finalMoneyAward)
	ServerData.UpdateBounty(killer, AwardConstants.PLAYER_KILL_BOUNTY)

	if victimBounty and victimBounty > 0 then
		ServerData.SetBounty(victim, 0)
		ServerSoundHandler:PlaySoundTo(killer, "BountyClaimed", nil)
	end
end
return AwardHandler
