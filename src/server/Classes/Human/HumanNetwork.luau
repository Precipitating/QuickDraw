local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanNetwork = {}

function HumanNetwork:IsLegless(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	return humanClass.Legless
end

HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork, { HumanNetwork.IsLegless })
return HumanNetwork
