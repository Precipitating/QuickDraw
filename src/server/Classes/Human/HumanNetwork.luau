local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanNetwork = {}

function HumanNetwork:IsLegless(key: Player | Humanoid)
	local humanClass = nil
	if key:IsA("Player") then
		humanClass = PlayerManager:GetHumanClassFromPlayer(key)
	elseif key:IsA("Humanoid") then
		humanClass = PlayerManager:GetHumanClass(key)
	else
		warn("[HumanNetwork:IsLegless] Key is incorrect")
		return nil
	end
	return humanClass.Legless
end

HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork, { HumanNetwork.IsLegless })
return HumanNetwork
