local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ToolsData = require(ReplicatedStorage.Shared.Classes.ToolsData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanRegistry = require(ServerScriptService.Server.Classes.Human.HumanRegistry)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = ClassTypes.Human
local ToolNetwork = {}

function ToolNetwork.ReduceTrapAmmo(player: Player)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass then
		Utility.Warn("Can't deduce ammo, human class missing")
		return
	end

	local trap = humanClass.Inventory and humanClass.Inventory:GetTrap()

	if not trap then
		Utility.Warn(`Can't reduce trap ammo,{player.Name} has no trap assigned`)
		return
	end

	trap:UpdateAmmo(-1)
end

function ToolNetwork:PlaceDownTrap(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass then
		return
	end

	local inventory = humanClass.Inventory
	if not inventory then
		return
	end

	local trap = inventory:GetTrap()
	if not trap then
		return
	end

	return trap:Place()
end

function ToolNetwork:HealPlayerFromTool(player: Player)
	if not player then
		return false
	end

	local humanClass = HumanRegistry:GetFromPlayer(player)
	if not humanClass then
		return false
	end

	local character = player.Character

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return false
	end

	if not tool:HasTag("HealItem") then
		return false
	end

	local toolData = ToolsData[tool.Name]
	if not toolData then
		return false
	end

	if toolData.HealAmount then
		local success = humanClass:HealInjuredPart(toolData.HealAmount)

		if success then
			humanClass.Inventory:RemoveItem(tool.Name)
			tool:Destroy()
			return true
		end
	end

	return false
end

ToolNetwork.networker = Networker.new(
	"ToolNetwork",
	ToolNetwork,
	{ ToolNetwork.ReduceTrapAmmo, ToolNetwork.PlaceDownTrap, ToolNetwork.HealPlayerFromTool }
)
return ToolNetwork
