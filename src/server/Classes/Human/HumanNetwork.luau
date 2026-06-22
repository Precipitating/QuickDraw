local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanNetwork = {}

function HumanNetwork:FinishedLoadingGame(player: Player)
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)

	if not ok then
		error(err)
	end
end

function HumanNetwork:GetCurrentGunName(player: Player)
	assert(player, "[ShopGUI:GetCurrentGun] Missing player argument")
	local human = PlayerManager:GetHumanClassFromPlayer(player)

	local currentGun = human.Inventory:GetGun()
	if not currentGun then
		warn("Error getting current gun")
		return nil
	end

	return currentGun.Name
end
function HumanNetwork:ToggleBackpackVisibility(player: Player, active: boolean, locked: boolean?)
	self.networker:fire(player, "ToggleBackpackVisibility", active, locked)
end

HumanNetwork.networker =
	Networker.new("HumanNetwork", HumanNetwork, { HumanNetwork.FinishedLoadingGame, HumanNetwork.GetCurrentGunName })
return HumanNetwork
