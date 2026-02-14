local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server
type Human = ClassTypes.Human
type Gun = ClassTypes.Gun
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

function ServerGunHandler:ActivateMuzzleFlash(player: Player, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end

	if not player then
		warn("[ServerGunHandler:ActivateMuzzleFlash] player invalid")
		return
	end

	self.networker:fireAllExcept(player, "ActivateMuzzleFlash", gunTool)
	print(`Server -> Client Muzzle Flash`)
end
ServerGunHandler.networker =
	Networker.new("GunNetwork", ServerGunHandler, { ServerGunHandler.ShootGun, ServerGunHandler.ActivateMuzzleFlash })

return ServerGunHandler
