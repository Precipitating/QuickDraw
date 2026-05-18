local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GamepassIds = require(ReplicatedStorage.Shared.GamepassIds)
local AwardConstants = require(script.Parent.AwardConstants)
local ServerData = require(script.Parent.Parent.ServerData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local AwardHandler = {}

function AwardHandler.OwnsGamePass(player: Player, gamePassId: number)
	local success, owned =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)

	if success and owned then
		print("Player owns the gamepass")
		return true
	end

	return false
end

function AwardHandler.AwardNPCKill(killer: Player)
	local ownsDoubleMoney = AwardHandler.OwnsGamePass(killer, GamepassIds.DoubleMoney)

	ServerData.UpdateMoney(
		killer,
		if ownsDoubleMoney then AwardConstants.NPC_KILL_AWARD * 2 else AwardConstants.NPC_KILL_AWARD
	)
	ServerData.UpdateBounty(
		killer,
		if ownsDoubleMoney then AwardConstants.NPC_KILL_AWARD * 2 else AwardConstants.NPC_KILL_BOUNTY
	)
end

function AwardHandler.AwardPlayerKill(victim: Player, killer: Player)
	local ownsDoubleMoney = AwardHandler.OwnsGamePass(killer, GamepassIds.DoubleMoney)

	-- award killer victim's bounty if exists
	local victimBounty = ServerData.GetBounty(victim)

	local finalMoneyAward = if victimBounty and victimBounty > 0
		then AwardConstants.PLAYER_KILL_AWARD + victimBounty
		else AwardConstants.PLAYER_KILL_AWARD

	ServerData.UpdateBank(killer, if ownsDoubleMoney then finalMoneyAward * 2 else finalMoneyAward)
	ServerData.UpdateBounty(
		killer,
		if ownsDoubleMoney then AwardConstants.PLAYER_KILL_BOUNTY * 2 else AwardConstants.PLAYER_KILL_BOUNTY
	)

	if victimBounty and victimBounty > 0 then
		ServerData.SetBounty(victim, 0)
		ServerSoundHandler:PlaySoundTo(killer, "BountyClaimed", nil)
	end
end
return AwardHandler
