local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
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

	local currentGun: Gun? = humanClass.Inventory:GetGun()
	if not currentGun then
		warn("[Reload] human class gun missing ref")
		return
	end

	return currentGun:Reload()
end

function ServerGunHandler:IsGunJammed(player: Player)
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	local gun = humanClass.Inventory and humanClass.Inventory:GetGun()
	if not gun or not humanClass then
		warn("Attempt gun jam failure, missing references")
		return nil
	end

	if gun.Jammed then
		PopupGUI:NewPopup(player, 1, "Gun jammed! press R to unjam")
	end
	return gun.Jammed
end

function ServerGunHandler:GunJamIfRolled(player: Player)
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	local gun = humanClass.Inventory and humanClass.Inventory:GetGun()
	if not gun or not humanClass then
		warn("Attempt gun jam failure, missing references")
		return
	end

	local gunData = GunData[gun.Name]
	if not gunData then
		warn("Attempt gun jam failure, missing gun data")
		return
	end

	if not gunData.JamChance then
		return
	end
	if RandomModule.GetRandom() > gunData.JamChance then
		return
	end

	gun.Jammed = true
	PopupGUI:NewPopup(player, 1, "Gun jammed")
end
function ServerGunHandler:UnjamGun(player: Player)
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	local gun = humanClass.Inventory and humanClass.Inventory:GetGun()
	if not gun or not humanClass then
		warn("Attempt gun jam failure, missing references")
		return
	end

	local gunData = GunData[gun.Name]
	if not gunData then
		warn("Attempt gun unjam failure, missing gun data")
		return
	end

	if not gunData.JamChance then
		return
	end

	ServerSoundHandler:PlaySoundTo(player, "UnjamWeapon")
	gun.Jammed = false
	PopupGUI:NewPopup(player, 1, "Gun unjammed")
end

function ServerGunHandler:GetAmmoCount(player: Player?)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)

	local currentGun: Gun? = humanClass.Inventory:GetGun()

	if not currentGun then
		return nil, nil, nil
	end
	local currentAmmo = currentGun.CurrentAmmo
	local maxAmmo = currentGun.MaxAmmo
	local ammoReserve = currentGun.AmmoReserve

	return currentAmmo, maxAmmo, ammoReserve
end

-- Server -> Client stop  gun reload
function ServerGunHandler:StopReloadingClient(player: Player)
	self.networker:fire(player, "StopReloading")
end

-- Client -> Server stop gun reload
function ServerGunHandler:StopReloadingServer(player: Player)
	if not player then
		return
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass then
		warn(`[ServerGunHandler:StopReloadingClient] Missing human class ref`)
		return
	end
	local inventory = humanClass and humanClass.Inventory
	if not inventory then
		warn(`[ServerGunHandler:StopReloadingClient] Missing human inventory ref`)
		return
	end

	local currentGun = inventory:GetGun()
	if not currentGun then
		warn(`[ServerGunHandler:StopReloadingClient] Missing currentGun ref`)
		return
	end

	if not currentGun.StopReloading then
		warn(`[ServerGunHandler:StopReloadingClient] Missing StopReloading function method`)
		return
	end
	currentGun:StopReloading(false)
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

	local gun = humanClass.Inventory and humanClass.Inventory:GetGun()

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
	ServerGunHandler.StopReloadingServer,
	ServerGunHandler.GunJamIfRolled,
	ServerGunHandler.IsGunJammed,
	ServerGunHandler.UnjamGun,
})

return ServerGunHandler
