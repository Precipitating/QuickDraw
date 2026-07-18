local ServerScriptService = game:GetService("ServerScriptService")
local AnimalHandler = require(ServerScriptService.Server.Classes.Animal.AnimalHandler)
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

	GunSignals.AnimalHit:Connect(function(hitData, hitObj: RaycastResult?, shooter: Player? | Model?)
		local hitInstance = hitObj and hitObj.Instance
		local animalParent = hitInstance and hitInstance.Parent
		local animalHumanoid = animalParent and animalParent:FindFirstChildOfClass("Humanoid")

		if not animalHumanoid then
			return
		end

		local animalClass = AnimalHandler:GetAnimal(animalHumanoid)
		if not animalClass then
			return
		end

		local gunShotData: ClassTypes.GunShotDamage = {
			Type = "Shot",
			RaycastResult = hitObj,
			TargetHuman = animalClass,
			Damage = hitData.Damage,
			ShotPosition = hitObj and hitObj.Instance and hitObj.Instance.Position,
			Shooter = shooter,
		}

		DamageModule.DamageAnimal(gunShotData)
	end),

	GunSignals.PlayerHit:Connect(
		function(
			hitObj: RaycastResult?,
			playerHumanoid: Humanoid?,
			damageInflicted: number,
			cosmeticBullet: BasePart?,
			shooter: Player? | Model?,
			canAffectShooter: boolean?
		)
			if not hitObj then
				warn("[GunSignals.PlayerHit] Hit object reference invalid")
				return
			end

			if not playerHumanoid then
				warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
				return
			end
			local humanClass = PlayerManager:GetHumanClass(playerHumanoid)

			-- if model, NPC or turret shot
			-- if player, player shot
			local shooterCharacter = if shooter and shooter:IsA("Player") then shooter.Character else shooter

			local shotPos = shooterCharacter and shooterCharacter:GetPivot().Position

			local gunShotData: ClassTypes.GunShotDamage = {
				Type = "Shot",
				CosmeticBulletObject = cosmeticBullet,
				RaycastResult = hitObj,
				TargetHuman = humanClass,
				Damage = damageInflicted,
				ShotPosition = shotPos,
				Shooter = shooter,
				CanAffectShooter = canAffectShooter,
			}

			DamageModule.DamageHuman(gunShotData)
		end
	),

	GunSignals.InflictLimbDamage:Connect(
		function(
			spreadParticleName: string,
			spreadDuration: number,
			damageInflicted: number,
			limb: MeshPart | BasePart,
			humanoid: Humanoid,
			shooter: Player?,
			humanoidType: string,
			canAffectShooter: boolean?
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

			if humanClass.Invincible then
				warn(`Invincible, not inflicting limb damage`)
				return
			end

			local shotData: ClassTypes.InflictingDamage = {
				Type = "Inflict",
				SpreadParticleName = spreadParticleName,
				SpreadDuration = spreadDuration,
				Damage = damageInflicted,
				TargetHuman = humanClass,
				HumanoidType = humanoidType,
				LimbHit = limb,
				Shooter = shooter,
				CanAffectShooter = canAffectShooter,
			}

			DamageModule:ApplyInflictingDamage(shotData)
		end
	),

	GunSignals.StoppedReloading:Connect(function(player: Player)
		ServerGunHandler:StopReloadingClient(player)
	end),
}
