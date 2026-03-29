local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local GunSignals = require(script.Parent.GunSignals)
local ServerGunHandler = require(script.Parent.ServerGunHandler)

type Human = ClassTypes.Human

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

	GunSignals.PlayerHit:Connect(
		function(hitObj: RaycastResult?, playerHumanoid: Humanoid?, damageInflicted: number, shotPos: Vector3)
			if not hitObj then
				warn("[GunSignals.PlayerHit] Hit object reference invalid")
				return
			end

			if not playerHumanoid then
				warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
				return
			end

			DamageModule.DamageHuman(hitObj, playerHumanoid, damageInflicted, shotPos)
		end
	),

	GunSignals.InflictLimbDamage:Connect(
		function(
			limb: MeshPart,
			damageInflicted: number,
			spreadParticleName: string,
			spreadDuration: number,
			humanoid: Humanoid
		)
			if not limb then
				warn("[GunSignals.PlayerHit] Limb reference invalid")
				return
			end
			if not humanoid then
				warn("[GunSignals.PlayerHit] humanoid reference invalid")
				return
			end

			local humanClass = PlayerManager:GetHumanClass(humanoid)

			if not humanClass then
				warn("[InflictLimbDamage] humanClass invalid")
				return
			end

			DamageModule:ApplyInflictingDamage(spreadParticleName, spreadDuration, damageInflicted, humanClass, limb)
		end
	),

	GunSignals.DisplayBulletHole:Connect(function(cframeTarget: CFrame?)
		assert(cframeTarget, "[GunSignals.DisplayBulletHole] cframeTarget is nil!")

		ServerGunHandler:DisplayBulletHole(cframeTarget)
	end),
}
