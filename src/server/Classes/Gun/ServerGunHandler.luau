local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
type Human = ClassTypes.Human
type Gun = ClassTypes.Gun
type Networker = NetworkServer

local ServerGunHandler = {}

function ServerGunHandler:Reload(player: Player?)
	if not player then
		return
	end

	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	local currentGun: Gun? = humanClass.CurrentGun
	if not currentGun then
		warn("[Reload] human class gun missing ref")
		return
	end

	return currentGun:Reload()
end

function ServerGunHandler:GetAmmoCount(player: Player?)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	local currentGun: Gun? = humanClass.CurrentGun
	local currentAmmo = if currentGun then currentGun.CurrentAmmo else nil
	local maxAmmo = if currentGun then currentGun.MaxAmmo else nil

	return currentAmmo, maxAmmo
end

function ServerGunHandler:StopReloading(player: Player)
	self.networker:fire(player, "StopReloading")
end
function ServerGunHandler:ReduceGunAmmo(player: Player)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass then
		warn("Can't deduce ammo, human class missing")
		return
	end

	local gun = humanClass.CurrentGun

	if not gun then
		warn(`Can't reduce gun ammo,{player.Name} has no gun assigned`)
		return
	end

	gun:UpdateAmmo(-1)
end
ServerGunHandler.networker = Networker.new("GunNetwork", ServerGunHandler, {
	ServerGunHandler.GetAmmoCount,
	ServerGunHandler.Reload,
	ServerGunHandler.ReduceGunAmmo,
})

return ServerGunHandler
