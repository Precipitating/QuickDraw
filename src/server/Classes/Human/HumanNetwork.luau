local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanNetwork = {}

function HumanNetwork:IsLegless(player: Player, humanoid: Humanoid?)
	local humanClass = nil
	if player:IsA("Player") and not humanoid then
		humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	elseif humanoid and humanoid:IsA("Humanoid") then
		humanClass = PlayerManager:GetHumanClass(humanoid)
	else
		warn("[HumanNetwork:IsLegless] Key is incorrect")
		return nil
	end
	return humanClass.Legless
end

function HumanNetwork:FinishedLoadingGame(player: Player)
	local humanClass = nil
	humanClass = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass then
		warn(`Missing human class for {player.Name} `)
		return
	end

	humanClass:SetInvincible(false, false)
	CollectionService:RemoveTag(player, "FirstLoad")

	warn("Invincibility on first spawn should be off")
end

HumanNetwork.networker =
	Networker.new("HumanNetwork", HumanNetwork, { HumanNetwork.IsLegless, HumanNetwork.FinishedLoadingGame })
return HumanNetwork
