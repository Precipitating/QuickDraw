local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
type Human = ClassTypes.Human
type Gun = ClassTypes.Gun
type Networker = NetworkServer

local ServerGunHandler = {}

function ServerGunHandler:ShootGun(player: Player, humanoid: Humanoid?)
	if not humanoid then
		warn("[ServerGunHandler:ShootGun] Humanoid nil, retrying with player instance")

		local model = player.Character

		if not model then
			error("[ServerGunHandler:ShootGun] Failed to get character!")
		end

		humanoid = model:FindFirstChild("Humanoid")

		if not humanoid then
			error("[ServerGunHandler:ShootGun] Failed to get humanoid!")
		end
	end
	if not humanoid then
		return
	end

	local humanClass: Human = PlayerManager:GetHumanClass(humanoid)
	local currentGun: Gun? = humanClass.CurrentGun

	if not currentGun then
		error(`[ServerGunHandler:ShootGun] No gun reference in human class`)
	end

	local hasShot = currentGun:ShootGun()

	return hasShot
end

function ServerGunHandler:ActivateMuzzleFlash(player: Player?, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	local shotPos = gunTool:FindFirstChild("Frame")
	if not shotPos then
		warn("ServerGunHandler:ActivateMuzzleFlash] Missing gun frame reference ")
		return
	end

	if player and player:IsA("Player") then
		self.networker:fireAllExcept(player, "ActivateMuzzleFlash", gunTool)

		ServerSoundHandler:Play3DOneShotToOthers(
			player,
			"RevolverShot",
			shotPos:GetPivot(),
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
		)
	else
		-- its an NPC, so fire all
		self.networker:fireAll("ActivateMuzzleFlash", gunTool)
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"RevolverShot",
			shotPos:GetPivot(),
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
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

function ServerGunHandler:DisconnectGun(player: Player)
	self.networker:fire(player, "DisconnectGun")
end
ServerGunHandler.networker =
	Networker.new("GunNetwork", ServerGunHandler, { ServerGunHandler.ShootGun, ServerGunHandler.ActivateMuzzleFlash })

return ServerGunHandler
