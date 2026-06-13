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

HumanNetwork.networker = Networker.new(
	"HumanNetwork",
	HumanNetwork,
	{ HumanNetwork.IsLegless, HumanNetwork.FinishedLoadingGame, HumanNetwork.GetCurrentGunName }
)
return HumanNetwork
