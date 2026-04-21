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

function ServerGunHandler:ActivateMuzzleFlash(player: Player?, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	local shotPos = gunTool:FindFirstChild("Frame", true)
	if not shotPos then
		warn("ServerGunHandler:ActivateMuzzleFlash] Missing gun frame reference ")
		return
	end

	if player and player:IsA("Player") then
		self.networker:fireAllExcept(player, "ActivateMuzzleFlash", gunTool)

		ServerSoundHandler:Play3DOneShotToOthers(
			player,
			GunData[gunTool.Name].ShootSoundName,
			shotPos:GetPivot(),
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
		)
	else
		-- its an NPC, so fire all
		self.networker:fireAll("ActivateMuzzleFlash", gunTool)
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			GunData[gunTool.Name].ShootSoundName,
			shotPos:GetPivot(),
			{ Pitch = 1 + (math.random() - 0.5) * 0.1, MaxDistance = 300 }
		)
	end

	print(`Server -> Client Muzzle Flash`)
end

function ServerGunHandler:DisplayBulletHole(cframeTarget: CFrame?)
	assert(cframeTarget, "[ServerGunHandler.DisplayBulletHole] cframeTarget is nil")
	self.networker:fireAll("DisplayBulletHole", cframeTarget)
end

function ServerGunHandler:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "[ServerGunHandler.DisplayBulletHole] position is nil")
	assert(normal, "[ServerGunHandler.DisplayBulletHole] normal is nil")
	self.networker:fireAll("DisplayBloodHit", position, normal)
end

ServerGunHandler.networker = Networker.new("GunNetwork", ServerGunHandler, {
	ServerGunHandler.ActivateMuzzleFlash,
	ServerGunHandler.GetAmmoCount,
	ServerGunHandler.Reload,
})

return ServerGunHandler
