local ServerScriptService = game:GetService("ServerScriptService")
local AnimalHandler = require(ServerScriptService.Server.Classes.Animal.AnimalHandler)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local LightweightNpcsServerAPI = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
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
			Shooter = shooter or hitData.Owner,
		}

		DamageModule.DamageAnimal(gunShotData)
	end),

	GunSignals.PlayerHit:Connect(
		function(
			hitObj: RaycastResult?,
			playerHumanoidOrID: Humanoid? | number?,
			damage: number,
			cosmeticBullet: BasePart?,
			shooter: Player? | Model?,
			canAffectShooter: boolean?
		)
			if not hitObj then
				warn("[GunSignals.PlayerHit] Hit object reference invalid")
				return
			end

			if not playerHumanoidOrID then
				warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
				return
			end
			local humanClass = nil --
			if typeof(playerHumanoidOrID) == "number" then
				humanClass = LightweightNpcsServerAPI:GetNpcById(playerHumanoidOrID)
			else
				humanClass = PlayerManager:GetHumanClass(playerHumanoidOrID)
			end

			-- if model, NPC or turret shot
			-- if player, player shot
			local shooterCharacter = if shooter and shooter:IsA("Player") then shooter.Character else shooter

			local shotPos = shooterCharacter and shooterCharacter:GetPivot().Position

			local gunShotData: ClassTypes.GunShotDamage = {
				Type = "Shot",
				CosmeticBulletObject = cosmeticBullet,
				RaycastResult = hitObj,
				TargetHuman = humanClass,
				Damage = damage,
				ShotPosition = shotPos,
				Shooter = shooter,
				CanAffectShooter = canAffectShooter,
			}

			-- Handle NPC hit logic elsewhere, combining it in DamageModule is messy.
			if typeof(playerHumanoidOrID) == "number" then
				humanClass.onHit:Fire(gunShotData)
				return
			end

			-- Should call if player gets hit.
			DamageModule.DamageHuman(gunShotData)
		end
	),

	GunSignals.ApplyLimbStatusDamage:Connect(
		function(
			spreadParticleName: string,
			spreadDuration: number,
			damagePerHit: number,
			limb: MeshPart | BasePart,
			humanoidOrNpcId: Humanoid | number,
			shooter: Player?,
			humanoidType: string,
			canAffectShooter: boolean?
		)
			if not limb then
				warn("[GunSignals.PlayerHit] Limb reference invalid")
				return
			end
			if not humanoidOrNpcId then
				warn("[GunSignals.PlayerHit] humanoid reference invalid")
				return
			end

			local targetClass = nil
			local target = humanoidOrNpcId :: any

			-- This only affects players as NPCs uses a different class
			if humanoidType == "Human" then
				targetClass = PlayerManager:GetHumanClass(target)
					or LightweightNpcsServerAPI:GetNpcById(humanoidOrNpcId :: number)

				if not targetClass then
					warn("[ApplyLimbStatusDamage] humanClass invalid")
					return
				end

				if targetClass.Invincible or targetClass.invincible then
					warn(`Invincible, not applying limb status damage`)
					return
				end
			elseif humanoidType == "Animal" then
				targetClass = AnimalHandler:GetAnimal(humanoidOrNpcId :: Humanoid)
				if not targetClass then
					warn("[ApplyLimbStatusDamage] animalClass invalid")
					return
				end
			end

			local shooterCharacter = if shooter and shooter:IsA("Player") then shooter.Character else shooter
			local shotPos = shooterCharacter and shooterCharacter:GetPivot().Position

			local shotData: ClassTypes.StatusDamage = {
				Type = "Status",
				SpreadParticle = spreadParticleName,
				SpreadDuration = spreadDuration,
				Damage = damagePerHit,
				TargetHuman = targetClass,
				HumanoidType = humanoidType,
				LimbHit = limb,
				ShotPosition = shotPos,
				Shooter = shooter,
				CanAffectShooter = canAffectShooter,
			}

			-- If NPC..
			if typeof(humanoidOrNpcId) == "number" then
				targetClass.onHit:Fire(shotData)
				return
			end

			DamageModule:ApplyStatusDamage(shotData)
		end
	),

	GunSignals.StoppedReloading:Connect(function(player: Player)
		ServerGunHandler:StopReloadingClient(player)
	end),
}
