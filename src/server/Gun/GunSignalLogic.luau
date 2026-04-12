local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
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
		function(hitObj: RaycastResult?, playerHumanoid: Humanoid?, damageInflicted: number, shooter: Player? | Model?)
			if not hitObj then
				warn("[GunSignals.PlayerHit] Hit object reference invalid")
				return
			end

			if not playerHumanoid then
				warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
				return
			end
			local humanClass = PlayerManager:GetHumanClass(playerHumanoid)

			-- if model, NPC shot
			-- if player, player shot
			-- if nil, its a throwable
			local shooterCharacter = if shooter and shooter:IsA("Player") then shooter.Character else shooter

			local hrp = if shooterCharacter
				then Utility.GetInstance(shooterCharacter, true, "HumanoidRootPart")
				else nil

			if not hrp then
				return
			end
			local gunShotData: ClassTypes.GunShotDamage = {
				Type = "Shot",
				RaycastResult = hitObj,
				TargetHuman = humanClass,
				Damage = damageInflicted,
				ShotPosition = hrp.Position,
				Shooter = shooter,
			}

			DamageModule.DamageHuman(gunShotData)
		end
	),

	GunSignals.InflictLimbDamage:Connect(
		function(
			spreadParticleName: string,
			spreadDuration: number,
			damageInflicted: number,
			limb: MeshPart,
			humanoid: Humanoid,
			shooter: Player?
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

			local shotData: ClassTypes.InflictingDamage = {
				Type = "Inflict",
				SpreadParticleName = spreadParticleName,
				SpreadDuration = spreadDuration,
				Damage = damageInflicted,
				TargetHuman = humanClass,
				LimbHit = limb,
				shooter = shooter,
			}

			DamageModule:ApplyInflictingDamage(shotData)
		end
	),

	GunSignals.DisplayBulletHole:Connect(function(cframeTarget: CFrame?)
		assert(cframeTarget, "[GunSignals.DisplayBulletHole] cframeTarget is nil!")

		ServerGunHandler:DisplayBulletHole(cframeTarget)
	end),
}
