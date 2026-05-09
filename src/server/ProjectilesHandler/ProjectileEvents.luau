local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GeneralProjectilesData = require(ReplicatedStorage.Shared.GeneralProjectilesData)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local ProjectileContext = require(script.Parent.ProjectileContext)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Effects = ReplicatedStorage.Shared.Effects
local ProjectileEvents = {}
local math_rad = math.rad
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_abs = math.abs
local math_sin = math.sin

type Destroyable = ClassTypes.Destroyable

local function GetHumanoidFromHit(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	return humanoid
end

function ProjectileEvents:GunHitPlayer(hitData, raycastResult: RaycastResult, owner: Player?)
	local hitHumanoid = GetHumanoidFromHit(raycastResult.Instance)
	local isAccessory = raycastResult.Instance:FindFirstAncestorOfClass("Accessory")

	if not hitHumanoid then
		return false
	end

	if isAccessory then
		return false
	end

	-- hit body part
	GunSignals.PlayerHit:Fire(raycastResult, hitHumanoid, hitData.Damage, owner or hitData.Owner)
	print(`{raycastResult.Instance.Name} hit!`)
	return true
end

function ProjectileEvents:GunHitDestroyable(hitData, raycastResult: RaycastResult, owner: Player?)
	local instance = raycastResult.Instance
	local destroyableClass: Destroyable = DestroyableManager.Destroyables[instance]
	if not destroyableClass then
		return
	end

	destroyableClass:Damage(hitData.Damage, owner or hitData.Owner)

	return true
end

function ProjectileEvents:FragmentHitPlayer(hit: RaycastResult, owner, throwableData)
	local isModel = hit.Instance:FindFirstAncestorOfClass("Model")
	if isModel then
		local humanoid = isModel:FindFirstChild("Humanoid")
		local isPlayer = if owner and typeof(owner) == "table" then owner.Character else owner
		if humanoid then
			if throwableData.Type == "Explosive" then
				GunSignals.PlayerHit:Fire(hit, humanoid, throwableData.Damage, isPlayer)
			elseif throwableData.Type == "Spread" then
				GunSignals.InflictLimbDamage:Fire(
					throwableData.SpreadParticle,
					throwableData.SpreadDuration,
					throwableData.Damage,
					hit.Instance,
					humanoid,
					isPlayer
				)
			end
			return true
		end
	end
	return false
end
local function RandomConeDirection(BaseDirection: Vector3, HalfAngleDeg: number): Vector3
	local HalfAngleRad = math_rad(HalfAngleDeg)
	local Phi = RandomModule.GetRandomDecimalBetween(0, math.pi * 2)
	local CosTheta = RandomModule.GetRandomDecimalBetween(math_cos(HalfAngleRad), 1)
	local SinTheta = math_sqrt(1 - CosTheta * CosTheta)

	local PerpendicularA =
		BaseDirection:Cross(math_abs(BaseDirection.X) < 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)).Unit
	local PerpendicularB = BaseDirection:Cross(PerpendicularA).Unit

	return (
		BaseDirection * CosTheta
		+ PerpendicularA * (SinTheta * math_cos(Phi))
		+ PerpendicularB * (SinTheta * math_sin(Phi))
	).Unit
end
function ProjectileEvents:FragmentHitDestroyable(hit: RaycastResult, throwableData)
	-- damage bodyparts if hits player
	local instance = hit.Instance
	local isDestroyable = CollectionService:HasTag(instance, "Destroyable")
	if isDestroyable then
		local destroyableClass = DestroyableManager:GetDestroyable(instance)
		if not destroyableClass then
			warn("[FragmentHitDestroyable] Destroyable class is not valid?")
			return
		end

		if throwableData.Type == "Explosive" then
			destroyableClass:Damage(throwableData.Damage)
		end

		return true
	end

	return false
end

function ProjectileEvents:FragmentHitEnvironment(hit: RaycastResult, throwableData)
	local explosiveType = throwableData.Type

	if not explosiveType then
		warn("Can't spawn fragment environment hit effect, missing ExplosiveType")
		return
	end

	if not hit then
		warn(`[ProjectileEvents:FragmentHitEnvironment] Missing raycastResult`)
		return
	end

	if explosiveType == "Explosive" then
		ServerEffectsDisplayer:DisplayProjectileMark("Bullet", hit)
	elseif explosiveType == "Spread" then
		ServerEffectsDisplayer:DisplayProjectileMark("Burn", hit)
	end
end

-- Used for throwable and destroyable radius limb damage
function ProjectileEvents:BodyPartDamage(damagedObject: BasePart?, explosiveData, initiator: Player | nil)
	if not damagedObject then
		return false
	end

	local parent = damagedObject.Parent
	local humanoid = if parent then parent:FindFirstChild("Humanoid") else nil
	local isBodyPart = damagedObject:IsA("MeshPart") and humanoid

	local dmg = explosiveData.BaseDamage or explosiveData.Damage
	local effectDuration = explosiveData.SpreadDuration or 0
	local damageType = explosiveData.HumanEffect or explosiveData.Type
	if isBodyPart then
		if damageType == "Spread" then
			GunSignals.InflictLimbDamage:Fire(
				explosiveData.SpreadParticle,
				effectDuration,
				dmg,
				damagedObject,
				humanoid,
				initiator
			)
		else
			if damageType == "Damage" then
				GunSignals.InflictLimbDamage:Fire(nil, 1, dmg, damagedObject, humanoid, initiator)
			end
		end
		return true
	end
	return false
end

function ProjectileEvents:ApplyThrowableRadiusDamage(origin: Vector3, radius: number, explosiveData, owner)
	local partsInRadius = workspace:GetPartBoundsInRadius(origin, radius)

	for _, obj in partsInRadius do
		-- affect humans only
		self:BodyPartDamage(obj, explosiveData, owner)
	end
end

-- For throwables
function ProjectileEvents:SpawnFragments(raycastResult: RaycastResult, owner, throwableData)
	if not raycastResult then
		warn(`[SERVER] Can't spawn fragments, raycast result is nil`)
		return
	end

	local center = raycastResult.Position
	local blastRadius = throwableData.BlastRadius

	-- apply radius damage first, for guaranteed damage within it
	self:ApplyThrowableRadiusDamage(center, blastRadius, throwableData, owner)

	-- spawn fragments on surface outwards from the radius
	for _ = 1, throwableData.FragmentCount do
		local randomDir = RandomConeDirection(Vector3.yAxis, 180)

		local surfaceResult = workspace:Raycast(center, randomDir * blastRadius)
		local origin = if surfaceResult then surfaceResult.Position else center + randomDir * blastRadius

		local context = ProjectileContext.BulletContext.new({
			Origin = origin,
			Direction = randomDir,
			Speed = 200,
		})
		context.UserData.ProjectileType = "Shrapnel"
		context.UserData.Data = throwableData
		context.UserData.Owner = owner
		ProjectileContext.Solver:Fire(context, GeneralProjectilesData.Shrapnel.ProjectileData)
	end
end

function ProjectileEvents:OnThrowImpact(impactParticleName: string, landPos: Vector3)
	if not Effects[impactParticleName] then
		warn("[Throwable:OnThrowImpact] Effect not valid to spawn")
		return
	end

	ServerEffectsDisplayer:DisplayDestroyParticle(impactParticleName, landPos)
end

-- This should be executed last, as every other option should be exhausted before deciding we've hit
-- the environment.
function ProjectileEvents:GunHitEnvironment(raycastResult: RaycastResult)
	-- hit environment
	ServerEffectsDisplayer:DisplayProjectileMark("Bullet", raycastResult)
end

function ProjectileEvents:OnProjectileHitReceiveServer(context, result: RaycastResult?)
	-- Hit nothing, the raycast hit the air and the lifetime of the projectile ends, hence nil
	if not result then
		return
	end
	--warn(`OnHit fired by server {result.Instance.Name}`)
	local data = context.UserData

	-- ON BULLET HIT
	if data.ProjectileType == "Bullet" then
		local hitPlayer = ProjectileEvents:GunHitPlayer(context.UserData, result)
		if hitPlayer then
			return
		end

		local hitDestroyable = ProjectileEvents:GunHitDestroyable(context.UserData, result)
		if hitDestroyable then
			return
		end

		ProjectileEvents:GunHitEnvironment(result)

		-- ON THROWABLE IMPACT LAND
	elseif data.ProjectileType == "Throwable" then
		local throwableData = data.Data
		ServerSoundHandler:Play3DOneShotToOthers(nil, throwableData.LandSound, result.Instance.CFrame)
		if context.CosmeticBulletObject then
			Debris:AddItem(context.CosmeticBulletObject, throwableData.DetonationTime)
		end
		task.delay(throwableData.DetonationTime, function()
			local hitPos = result.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				throwableData.DetonationSound,
				result.Instance.CFrame,
				{ MaxDistance = 150 }
			)

			ServerEffectsDisplayer:DisplayDestroyParticle(throwableData.ImpactParticle, hitPos)
			self:SpawnFragments(result, data.Class.Owner, throwableData)
			if data.Class.CurrentAmmo <= 0 then
				data.Class:Destroy()
			end
		end)
		-- ON SHRAPNEL HIT
	elseif data.ProjectileType == "Shrapnel" then
		self:OnFragmentHit(context, result)
	end
end

function ProjectileEvents:OnFragmentHit(context, result: RaycastResult?)
	-- if fragment hits something damagable, it should apply damage and cease to exist
	if not result then
		return
	end

	local throwableData = context.UserData.Data
	local owner = context.UserData.Owner
	-- handle hitting player
	if self:FragmentHitPlayer(result, owner, throwableData) then
		return
	end

	-- handle hitting destroyables
	if self:FragmentHitDestroyable(result, throwableData) then
		return
	end

	-- else hit environment
	self:FragmentHitEnvironment(result, throwableData)
end

function ProjectileEvents:OnProjectileHitReceivePlayer(context, result: RaycastResult?)
	-- Hit nothing, the raycast hit the air and the lifetime of the projectile ends, hence nil
	if not result then
		return
	end
	warn(`OnHit fired by player. Hit object: {result.Instance.Name}`)

	-- GUN PROJECTILES
	if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
		local human = PlayerManager:GetHumanClassFromPlayer(context.UserData.Owner)
		local currentGunName = human.CurrentGun and human.CurrentGun.GunName
		if not currentGunName then
			return
		end
		local gunData = GunData[currentGunName]
		if not gunData then
			warn("GunData missing from OnProjectileHitReceivePlayer")
			return
		end

		local hitPlayer = ProjectileEvents:GunHitPlayer(gunData, result, context.UserData.Owner)
		if hitPlayer then
			return
		end

		local hitDestroyable = ProjectileEvents:GunHitDestroyable(gunData, result, context.UserData.Owner)
		if hitDestroyable then
			return
		end

		-- THROWABLE PROJECTILES
	elseif CollectionService:HasTag(context.CosmeticBulletObject, "Throwable") then
		local data = context.UserData
		local human = PlayerManager:GetHumanClassFromPlayer(data.Owner)
		local throwable = human.CurrentThrowable
		local throwableName = throwable and human.CurrentThrowable.Name
		if not throwableName then
			return
		end
		local throwableData = ThrowableData[throwableName]

		ServerSoundHandler:Play3DOneShotToOthers(nil, throwableData.LandSound, result.Instance.CFrame)

		if context.CosmeticBulletObject then
			Debris:AddItem(context.CosmeticBulletObject, throwableData.DetonationTime)
		end

		task.delay(throwableData.DetonationTime, function()
			local hitPos = result.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				throwableData.DetonationSound,
				result.Instance.CFrame,
				{ MaxDistance = 150 }
			)

			self:OnThrowImpact(throwableData.ImpactParticle, hitPos)
			self:SpawnFragments(result, data.Owner, throwableData)

			if throwable.CurrentAmmo <= 0 then
				throwable:Destroy()
			end
		end)
	end
end

function ProjectileEvents:Initialize()
	ProjectileContext.VetraSignals.OnPierce:Connect(function(context, result, velocity, pierceCount: number)
		print("OnPierce fired")
	end)

	ProjectileContext.Net.OnFireRejected:Connect(function(player, reason)
		warn(`Rejected projectile hit because of {reason}`)
	end)

	-- for NPCS/Server
	ProjectileContext.Solver:GetSignals().OnHit:Connect(function(context, result, velocity)
		local owner = context.UserData.Owner
		if owner and typeof(owner) == "Instance" and owner:IsA("Player") then
			if context.UserData.ProjectileType ~= "Shrapnel" then
				return
			end
		end
		self:OnProjectileHitReceiveServer(context, result)
	end)

	-- players firing from client
	ProjectileContext.Net.OnValidatedHit:Connect(function(player, context, result, velocity, impactForce)
		if not result then
			return
		end
		context.UserData["Owner"] = player
		self:OnProjectileHitReceivePlayer(context, result)
	end)
end

return ProjectileEvents
