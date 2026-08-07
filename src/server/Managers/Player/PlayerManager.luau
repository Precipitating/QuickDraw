local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanNPC = require(ServerScriptService.Server.Classes.Human.HumanNPC)
local HumanPlayer = require(ServerScriptService.Server.Classes.Human.HumanPlayer)
local HumanRegistry = require(ServerScriptService.Server.Classes.Human.HumanRegistry)
type HumanPlayer = ClassTypes.HumanPlayer

local PlayerManager = {}

function PlayerManager:AddHumanClass(player: Player)
	if not player then
		warn(`Attempting to add a Human class, but player is {player}`)
		return
	end
	local character = player.Character
	local humanoid = character:WaitForChild("Humanoid")
	local humanClass = HumanPlayer.new(humanoid, player)
	return HumanRegistry:Add(humanoid, humanClass)
end

function PlayerManager:AddHumanClassNPC(
	lightweightNPCClass: {},
	humanoid: Humanoid?,
	classType: string,
	factionType: string,
	optionalData: any?
)
	assert(humanoid, "[PlayerManager:AddHumanClassNPC] should be humanoid argument!")
	local humanClass = HumanNPC.new(lightweightNPCClass, humanoid, classType, optionalData)
	return HumanRegistry:Add(humanoid, humanClass)
end

function PlayerManager:RemoveHumanClass(humanoid: Humanoid)
	if not humanoid then
		return
	end
	HumanRegistry:Remove(humanoid)
end

function PlayerManager:GetHumanClass(key: Humanoid?)
	return HumanRegistry:Get(key)
end

function PlayerManager:GetHumanClassFromPlayer(player: Player)
	return HumanRegistry:GetFromPlayer(player)
end

return PlayerManager
