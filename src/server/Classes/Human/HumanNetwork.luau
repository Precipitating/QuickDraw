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

HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork, { HumanNetwork.IsLegless })
return HumanNetwork
