local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Human = require(ServerScriptService.Server.Classes.Human)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = Human.Human
type Gun = Gun.Gun
type Networker = NetworkServer

local ServerGunHandler = {}

ServerGunHandler.janitor = Janitor.new()

function ServerGunHandler:ShootGun(player: Player)
	local humanClass: Human = PlayerManager:GetHumanClass(player)
	local currentGun: Gun = humanClass.CurrentGun

	if not currentGun then
		error(`{player.DisplayName} has no gun`)
	end

	local hasShot = currentGun:ShootGun()

	return hasShot
end

ServerGunHandler.GunNetwork = Networker.new("GunNetwork", ServerGunHandler, { ServerGunHandler.ShootGun })
return ServerGunHandler
