local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCEvents = require(ServerScriptService.Server.NPCEvents)
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local BASE_TARGET_COST = 1250
local MercenaryHandler = {}

function MercenaryHandler:GetTargetCost(player: Player)
	local playerBounty = ServerData:GetBounty(player)
	return BASE_TARGET_COST + (playerBounty * 2)
end
function MercenaryHandler:BuyTarget(player: Player, target: Player, cost: number)
	local playerMoney = ServerData.GetMoney(player)

	-- DEBUG, REMOVE LATER
	cost = 0
	--

	if playerMoney < cost then
		return false
	end

	ServerData.UpdateMoney(player, -cost)
	CollectionService:AddTag(target.Character, target.Name)
	NPCEvents.AddTarget(target)
	return true
end

MercenaryHandler.networker =
	Networker.new("MercenaryNetwork", MercenaryHandler, { MercenaryHandler.GetTargetCost, MercenaryHandler.BuyTarget })

return MercenaryHandler
