local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Human = require(ServerScriptService.Server.Classes.Human)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = Human.Human
type Gun = Gun.Gun
type Networker = NetworkServer

local ServerGunHandler = {}

function ServerGunHandler:ShootGun(player: Player)
	local humanClass: Human = PlayerManager:GetHumanClass(player)
	local currentGun: Gun? = humanClass.CurrentGun

	if not currentGun then
		error(`{player.DisplayName} has no gun`)
	end

	local hasShot = currentGun:ShootGun()

	return hasShot
end

function ServerGunHandler:ActivateMuzzleFlash(player: Player, muzzleFolder: Attachment)
	if not muzzleFolder then
		warn("[ServerGunHandler:ActivateMuzzleFlash] muzzleFolder invalid")
		return
	end

	if not player then
		warn("[ServerGunHandler:ActivateMuzzleFlash] player invalid")
		return
	end

	--self.networker:fire(player, "ActivateMuzzleFlash", muzzleFolder)
	self.networker:fireAllExcept(player, "ActivateMuzzleFlash", muzzleFolder)
	print(`Server -> Client Muzzle Flash`)
end
ServerGunHandler.networker =
	Networker.new("GunNetwork", ServerGunHandler, { ServerGunHandler.ShootGun, ServerGunHandler.ActivateMuzzleFlash })

return ServerGunHandler
