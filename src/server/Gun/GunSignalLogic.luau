local ServerScriptService = game:GetService("ServerScriptService")
local DamageModule = require(ServerScriptService.Server.DamageModule)
local GunSignals = require(script.Parent.GunSignals)
local ServerGunHandler = require(script.Parent.ServerGunHandler)

return {
	GunSignals.ConnectGunSignal:Connect(function(player: Player, gun: Tool)
		print("Gun connect signal fired!")
		ServerGunHandler.networker:fire(player, "ConnectGun", gun)
	end),

	GunSignals.FireMuzzleFlash:Connect(function(player: Player?, gunTool: Tool?)
		if not gunTool then
			warn("[GunSignals.FireMuzzleFlash] gun tool ref invalid")
			return
		end
		ServerGunHandler:ActivateMuzzleFlash(player, gunTool)
	end),

	GunSignals.PlayerHit:Connect(function(hitObj: RaycastResult?, playerHumanoid: Humanoid?, damageInflicted: number)
		if not hitObj then
			warn("[GunSignals.PlayerHit] Hit object reference invalid")
			return
		end

		if not playerHumanoid then
			warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
			return
		end

		DamageModule.DamageHuman(hitObj, playerHumanoid, damageInflicted)
	end),

	GunSignals.DisplayBulletHole:Connect(function(cframeTarget: CFrame?)
		assert(cframeTarget, "[GunSignals.DisplayBulletHole] cframeTarget is nil!")

		ServerGunHandler:DisplayBulletHole(cframeTarget)
	end),

	GunSignals.DisconnectGun:Connect(function(player: Player)
		assert(player, "[GunSignals.DisconnectGun] player is nil!")
		ServerGunHandler:DisconnectGun(player)
	end),
}
