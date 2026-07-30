local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local ServerScreenEffects = require(script.Parent.ServerScreenEffects)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
type Human = ClassTypes.Human
type HumanPlayer = ClassTypes.HumanPlayer
type HumanNPC = ClassTypes.HumanNPC

local LimbDamageMultiplier = {
	Head = 2.5,
	UpperTorso = 1.05,
	LowerTorso = 1.05,

	LeftUpperArm = 0.49,
	LeftLowerArm = 0.49,
	RightUpperArm = 0.49,
	RightLowerArm = 0.49,

	LeftUpperLeg = 0.7,
	LeftLowerLeg = 0.7,
	RightUpperLeg = 0.7,
	RightLowerLeg = 0.7,
}

local DamageModule = {}

local function ApplyDamageHighlight(humanClass: Human, limbName: string)
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = humanClass.BodyParts[limbName]
	Debris:AddItem(highlight, 0.5)
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
end

function DamageModule:ApplyDamage(
	human: HumanPlayer | HumanNPC,
	limbName: string,
	damage: number,
	shotPos: Vector3,
	shooter: Player | Model
)
	if not human or not human.LimbHealth or not human.LimbHealth[limbName] or human.Dead or human.Invincible then
		return
	end
	local gun = human.Inventory and human.Inventory:GetGun()

	if gun then
		local reloading = gun.Reloading

		-- stop reloading if hurt
		if reloading then
			gun:StopReloading()
		end
	end

	if human.HumanType == "NPC" then
		human = human :: HumanNPC
		local ai = human.AI

		-- if npc damaged on patrol, seek immediately the target
		-- only applies to SHOT damage type

		if ai and ai.StateMachine:GetState() == "Patrol" then
			local shooterCharacter = nil

			-- If table, should be the Human class, so .Character should be its model.
			-- Same with if it's Player instance

			if
				(typeof(shooter) == "table" and shooter.Character)
				or typeof(shooter) == "Instance" and shooter:IsA("Player")
			then
				shooterCharacter = shooter.Character
			else
				shooterCharacter = shooter
			end

			-- Check if shooterCharacter is valid (not nil and not an empty table)
			local isValidTarget = false

			if typeof(shooterCharacter) == "Instance" then
				isValidTarget = true
			elseif typeof(shooterCharacter) == "table" then
				isValidTarget = next(shooterCharacter) ~= nil -- True only if table has elements
			end

			if isValidTarget then
				ai.StateMachine:Transition("Seek", {
					Target = shooterCharacter,
				})
			else
				warn("Invalid or empty shooter target:", shooterCharacter)
			end
		end
	elseif human.HumanType == "Player" then
		human = human :: HumanPlayer
		human:AdjustGrayscale()
	end

	local multiplier = LimbDamageMultiplier[limbName] or 1

	if not human or human.Dead or not human.OnHit then
		return
	end

	human:OnHit(damage, multiplier, limbName, shooter)

	ApplyDamageHighlight(human, limbName)
end

function DamageModule:ApplyInflictingDamage(inflictingDamageData: ClassTypes.InflictingDamage)
	local spreadParticleName = inflictingDamageData.SpreadParticleName
	local damagedLimb = inflictingDamageData.LimbHit
	local spreadDuration = inflictingDamageData.SpreadDuration
	local humanoidType = inflictingDamageData.HumanoidType
	local targetHuman = inflictingDamageData.TargetHuman

	if not humanoidType then
		warn("[ApplyInflictingDamage]: Missing humanoid type")
		return
	end

	if spreadParticleName then
		ServerEffectsDisplayer:DisplaySpreadParticle(spreadParticleName, spreadDuration, damagedLimb)
	end

	local damageFunction = function()
		if humanoidType == "Human" then
			self.DamageHuman(inflictingDamageData)
		elseif humanoidType == "Animal" then
			self.DamageAnimal(inflictingDamageData)
		end
	end

	task.spawn(function()
		for _ = 1, spreadDuration do
			if targetHuman.Dead then
				return
			end
			damageFunction()
			task.wait(1)
		end
	end)
end

local function HandleLimbDestroyed(humanClass: Human, limbName: string, damage: number)
	if not humanClass or not humanClass.LimbHealth or not humanClass.LimbHealth[limbName] then
		return
	end

	if limbName ~= "UpperTorso" and limbName ~= "LowerTorso" then
		if humanClass.LimbHealth[limbName] <= HumanConstants.LIMB_DISMEMBER_HP then
			humanClass:DestroyLimb(limbName)
			return
		end
	end

	humanClass:DisableLimb(limbName)

	-- Vital limb = instant death
	if limbName == "Head" or limbName == "UpperTorso" or limbName == "LowerTorso" then
		humanClass.Health = 0
		return
	end

	-- Blacked limb = spread damage to all limbs
	task.spawn(function()
		for name in humanClass.LimbHealth do
			humanClass.LimbHealth[name] -= damage
		end
	end)
end

local function ApplyHumanRepercussionsAfterShot(human: Human, cosmeticBullet: BasePart?)
	if not cosmeticBullet or not human then
		return
	end

	-- Ragdoll and get blown back strongly
	if CollectionService:HasTag(cosmeticBullet, "CannonBall") then
		local force = 150
		local dir: Vector3 = (human.HRP.Position - cosmeticBullet.Position).Unit * human.HRP.AssemblyMass * force
		print("Impulse dir:", dir, "| Magnitude:", dir.Magnitude)
		human:Ragdoll(5)
		task.defer(function()
			human:ApplyImpulse(dir)
			if human.Player then
				ServerScreenEffects:ApplyOneShotEffect(human.Player, "CannonballHit")
			end
		end)
	end
end

local function CheckAndHandleLimbDestroyed(human: Human, damage: number, limbName: string)
	local limbHealth = human.LimbHealth
	local limbHP = limbHealth[limbName]

	if limbHP and limbHealth[limbName] <= 0 then
		HandleLimbDestroyed(human, limbName, damage)
	end
end

local function CheckAndHandleDeadHuman(human: Human, shooter: Player?)
	if human.Health <= 0 then
		human:Die(shooter)
	end
end
function DamageModule.DamageAnimal(damageData: ClassTypes.GunShotDamage | ClassTypes.InflictingDamage)
	if not damageData then
		return
	end

	local animalClass = damageData.TargetHuman
	-- Inflicting Damage does not have RaycastResult, so it will only display blood if we do.
	local raycastResult = (damageData :: any).RaycastResult
	if not animalClass then
		warn("Missing animal class.")
		return
	end

	local damage = damageData.Damage
	animalClass:UpdateHealth(-damage, damageData.Shooter)
	if raycastResult then
		ServerEffectsDisplayer:DisplayBloodHit(raycastResult.Position, raycastResult.Normal)
	end

	-- Set animal to seek state when shot, aggroing them.
	local ai = animalClass.AI
	if ai then
		if ai.StateMachine and ai.StateMachine.Transition then
			local currentAnimalState = ai.StateMachine:GetState()
			local shooter = damageData.Shooter

			if shooter then
				if currentAnimalState == "Patrol" then
					local shooterCharacter = nil
					if
						(typeof(shooter) == "table" and shooter.Character)
						or typeof(shooter) == "Instance" and shooter:IsA("Player")
					then
						shooterCharacter = shooter.Character
					else
						shooterCharacter = shooter
					end
					ai.StateMachine:Transition("Seek", { Target = shooterCharacter })
				end
			end
		end
	end

	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		`{animalClass.ClassType}Hit`,
		animalClass.Character:GetPivot().Position,
		{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
	)
	warn(`DAMAGED ANIMAL`)
end
function DamageModule.DamageHuman(
	damageData: ClassTypes.InflictingDamage | ClassTypes.GunShotDamage | ClassTypes.TrapDamage | ClassTypes.BargeDamage
)
	local hitObj = nil
	if damageData.Type == "Shot" then
		hitObj = damageData.RaycastResult
	else
		hitObj = damageData.LimbHit
	end
	local human = damageData.TargetHuman

	if not human then
		return
	end
	if human.Invincible then
		warn("invicible, cant hit")
		return
	end

	if not damageData.CanAffectShooter and damageData.Shooter == (human and human.Player) then
		warn("Player attempted to shoot themself, denied")
		return
	end

	local limbHealth = human.LimbHealth
	local damage = damageData.Damage
	local shooter = damageData.Shooter
	local shotPos = if damageData.Type == "Shot" then damageData.ShotPosition else nil
	local cosmeticBulletObj = damageData.CosmeticBulletObject
	if not hitObj then
		warn("[DamageHuman] Invalid hit object")
		return
	end
	if human.Dead or not limbHealth then
		return
	end

	local limbName = nil

	local hitType = typeof(hitObj)
	local instanceRef

	if hitType == "Instance" then
		instanceRef = hitObj
	elseif hitType == "RaycastResult" or hitType == "table" then
		instanceRef = hitObj.Instance
	end

	if instanceRef then
		limbName = instanceRef.Name
	end

	if not limbHealth[limbName] then
		return
	end

	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		"BulletHitGroan",
		human.HRP.Position,
		{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
	)

	-- Apply special logic that may occur after being shot by a specific bullet type

	DamageModule:ApplyDamage(human, limbName, damage, shotPos, shooter)
	ApplyHumanRepercussionsAfterShot(human, cosmeticBulletObj)

	CheckAndHandleLimbDestroyed(human, damage, limbName)
	CheckAndHandleDeadHuman(human, shooter)
	if not human or not human.Health then
		return
	end

	if typeof(hitObj) == "RaycastResult" then
		ServerEffectsDisplayer:DisplayBloodHit(hitObj.Position, hitObj.Normal)
	end
end

return DamageModule
