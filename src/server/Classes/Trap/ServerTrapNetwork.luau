local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = ClassTypes.Human
local ServerTrapNetwork = {}

function ServerTrapNetwork.ReduceTrapAmmo(player: Player)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass then
		warn("Can't deduce ammo, human class missing")
		return
	end

	local trap = humanClass.Inventory and humanClass.Inventory:GetTrap()

	if not trap then
		warn(`Can't reduce trap ammo,{player.Name} has no trap assigned`)
		return
	end

	trap:UpdateAmmo(-1)
end

function ServerTrapNetwork:PlaceDownTrap(player: Player)
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

ServerTrapNetwork.networker = Networker.new(
	"TrapNetwork",
	ServerTrapNetwork,
	{ ServerTrapNetwork.ReduceTrapAmmo, ServerTrapNetwork.PlaceDownTrap }
)
return ServerTrapNetwork
