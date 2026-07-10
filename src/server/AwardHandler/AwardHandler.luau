local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local QuestHandler = require(ServerScriptService.Server.Quests.QuestHandler)
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

	local awardAmount = if ownsDoubleMoney then AwardConstants.NPC_KILL_AWARD * 2 else AwardConstants.NPC_KILL_AWARD
	local bounty = if ownsDoubleMoney then AwardConstants.NPC_KILL_AWARD * 2 else AwardConstants.NPC_KILL_BOUNTY

	ServerData.UpdateMoney(killer, awardAmount)
	ServerData.UpdateBounty(killer, bounty)

	PopupGUI:NewPopup(killer, 2, `NPC killed: ${awardAmount}`)
	PopupGUI:NewPopup(killer, 2, `Bounty: +${bounty}`)

	QuestHandler:ProgressQuest(killer, "Kill", 1)
end

function AwardHandler.AwardPlayerKill(victim: Player, killer: Player)
	local ownsDoubleMoney = AwardHandler.OwnsGamePass(killer, GamepassIds.DoubleMoney)

	-- award killer victim's bounty if exists
	local victimBounty = ServerData.GetBounty(victim)

	local finalMoneyAward = if victimBounty and victimBounty > 0
		then AwardConstants.PLAYER_KILL_AWARD + victimBounty
		else AwardConstants.PLAYER_KILL_AWARD

	finalMoneyAward = if ownsDoubleMoney then finalMoneyAward * 2 else finalMoneyAward
	local killerNewBounty = if ownsDoubleMoney
		then AwardConstants.PLAYER_KILL_BOUNTY * 2
		else AwardConstants.PLAYER_KILL_BOUNTY

	ServerData.UpdateBank(killer, finalMoneyAward)
	PopupGUI:NewPopup(
		killer,
		2,
		if victimBounty
			then `{killer.Name} killed! Bounty claimed +${finalMoneyAward}`
			else `{killer.Name} killed! +${finalMoneyAward}`
	)
	ServerData.UpdateBounty(killer, killerNewBounty)
	PopupGUI:NewPopup(killer, 2, `Bounty: +${killerNewBounty}`)

	if victimBounty and victimBounty > 0 then
		ServerData.SetBounty(victim, 0)
		ServerSoundHandler:PlaySoundTo(killer, "BountyClaimed", nil)
	end

	QuestHandler:ProgressQuest(killer, "Kill", 1)
end
return AwardHandler
