local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
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
local HumanNetwork = require(ServerScriptService.Server.Classes.Human.HumanNetwork)
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

local RAY_DISTANCE = 60 -- max distance for straight + fan raycasts
local SPHERE_RADIUS = 2.5 -- radius for spherecast sweep
local FAN_ANGLE_OFFSET = 0.3 -- how far off-axis the fan raycasts angle
local SPATIAL_SEARCH_AHEAD = 10 -- how far ahead of hit to centre the bounds search
local SPATIAL_SEARCH_RADIUS = 8 -- radius of the spatial bounds search

local MaterialHitData = {
	[Enum.Material.Glass] = {
		HitSound = "GlassSmash",
		Destroy = true,
		HitParticle = "GlassShatter",
	},
}

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

function ProjectileEvents:GunHitPlayer(hitData, raycastResult: RaycastResult, owner: Player?, bulletCosmetic: BasePart?)
	local hitHumanoid = GetHumanoidFromHit(raycastResult.Instance)
	local isAccessory = raycastResult.Instance:FindFirstAncestorOfClass("Accessory")

	if not hitHumanoid then
		return false
	end

	if isAccessory then
		return false
	end

	-- hit body part
	GunSignals.PlayerHit:Fire(raycastResult, hitHumanoid, hitData.Damage, bulletCosmetic, owner or hitData.Owner)
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

function ProjectileEvents:ApplyHookSubEffect(hit: RaycastResult, duration: number)
	if not hit or not duration then
		warn("ApplyHookSubEffect: missing arguments")
		return
	end

	local limbPart = hit.Instance :: BasePart
	if not limbPart or not limbPart.Parent then
		return
	end

	local character = limbPart.Parent
	if not character:FindFirstChildOfClass("Humanoid") then
		return
	end

	local hitPlayer = Players:GetPlayerFromCharacter(character)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- hit.Normal points back at the shooter, so negate it to get travel direction
	local travelDir = -hit.Normal

	-- ── Anchor search (tries each strategy until one succeeds) ────────────

	local anchorPos: Vector3
	local anchorInstance: BasePart

	-- Strategy 1: straight raycast in travel direction
	local straightRay = workspace:Raycast(hit.Position, travelDir * 0.2, rayParams)
	if straightRay and straightRay.Instance.CollisionGroup ~= "Ground" then
		anchorPos = straightRay.Position
		anchorInstance = straightRay.Instance
	end

	-- Strategy 2: spherecast — catches walls the straight ray narrowly misses
	if not anchorPos then
		local sphereRay = workspace:Spherecast(hit.Position, SPHERE_RADIUS, travelDir * 0.2, rayParams)
		if sphereRay and sphereRay.Instance.CollisionGroup ~= "Ground" then
			anchorPos = sphereRay.Position
			anchorInstance = sphereRay.Instance
		end
	end

	-- Strategy 3: fan raycasts at slight angles
	if not anchorPos then
		for _, offset in { Vector3.yAxis, -Vector3.yAxis, Vector3.xAxis, -Vector3.xAxis } do
			local fanDir = (travelDir + offset * FAN_ANGLE_OFFSET).Unit
			local fanRay = workspace:Raycast(hit.Position, fanDir * RAY_DISTANCE, rayParams)
			if fanRay and fanRay.Instance.CollisionGroup ~= "Ground" then
				anchorPos = fanRay.Position
				anchorInstance = fanRay.Instance
				break
			end
		end
	end

	-- Strategy 4: spatial query for any nearby anchored part
	if not anchorPos then
		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = { character }
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		local nearby = workspace:GetPartBoundsInRadius(
			hit.Position + travelDir * SPATIAL_SEARCH_AHEAD,
			SPATIAL_SEARCH_RADIUS,
			overlapParams
		)
		for _, part in nearby do
			if part:IsA("BasePart") and part.Anchored and part.CollisionGroup ~= "Ground" then
				anchorPos = part.Position
				anchorInstance = part
				break
			end
		end
	end

	if hitPlayer then
		HumanNetwork:ToggleBackpackVisibility(hitPlayer, false, true)
	end

	-- ─────────────── Attachments ───────────────

	if not anchorPos then
		return
	end
	local limbAttach = Instance.new("Attachment")
	limbAttach.Parent = limbPart
	limbAttach.WorldPosition = hit.Position

	local endAttach = Instance.new("Attachment")
	endAttach.Parent = anchorInstance
	endAttach.WorldPosition = anchorPos

	-- ── Rope ─────────────────────────────────────────────────────────────

	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = endAttach
	rope.Attachment1 = limbAttach
	rope.Length = (hit.Position - anchorPos).Magnitude
	rope.Restitution = 0
	rope.Visible = true
	rope.Thickness = 0.2
	rope.Parent = limbPart

	task.delay(duration, function()
		if limbAttach and limbAttach.Parent then
			limbAttach:Destroy()
		end
		if endAttach and endAttach.Parent then
			endAttach:Destroy()
		end
		if rope and rope.Parent then
			rope:Destroy()
		end
		if hitPlayer then
			HumanNetwork:ToggleBackpackVisibility(hitPlayer, true, false)
		end
	end)
end

function ProjectileEvents:HandleSubTypes(subtype: string, duration: number, hit: RaycastResult)
	if not hit then
		return
	end

	if subtype == "Hook" then
		self:ApplyHookSubEffect(hit, duration)
	end
end

function ProjectileEvents:FragmentHitPlayer(hit: RaycastResult, owner, throwableData, cosmeticBullet: BasePart?)
	local isModel = hit.Instance:FindFirstAncestorOfClass("Model")
	if isModel then
		local humanoid = isModel:FindFirstChild("Humanoid")
		local isPlayer = if owner and typeof(owner) == "table" then owner.Character else owner
		if humanoid then
			if throwableData.Type == "Explosive" then
				GunSignals.PlayerHit:Fire(hit, humanoid, throwableData.Damage, cosmeticBullet, isPlayer, true)
			elseif throwableData.Type == "Spread" then
				GunSignals.InflictLimbDamage:Fire(
					throwableData.SpreadParticle,
					throwableData.SpreadDuration,
					throwableData.Damage,
					hit.Instance,
					humanoid,
					isPlayer,
					true
				)
			end

			-- special effects add-on
			task.spawn(function()
				if throwableData.Subtype and throwableData.SubtypeEffectDuration then
					self:HandleSubTypes(throwableData.Subtype, throwableData.SubtypeEffectDuration, hit)
				end
			end)

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

function ProjectileEvents:ApplyExplosionForce(
	target: BasePart,
	explosionCenter: Vector3,
	force: number,
	impulseAppliedList: {}
)
	local hasModel = target.Parent
	if not hasModel or not hasModel:FindFirstChild("Humanoid") then
		return
	end

	local humanoid = hasModel:FindFirstChild("Humanoid")
	if impulseAppliedList[humanoid] then
		return
	end
	impulseAppliedList[humanoid] = true

	local humanClass = PlayerManager:GetHumanClass(humanoid)

	if not humanClass then
		return
	end

	if humanClass.Ragdoll then
		humanClass:Ragdoll(3)
	end

	if target.Anchored then
		return
	end

	local direction = target.Position - explosionCenter
	if direction.Magnitude == 0 then
		direction = Vector3.new(0, 1, 0) -- Safe fallback if center is identical to root
	else
		-- Normalize the actual direction, then blend in a slight upward trajectory
		direction = (direction.Unit + Vector3.new(0, 0.5, 0)).Unit
	end

	if humanClass.ApplyImpulse then
		humanClass:ApplyImpulse(direction * force * target.AssemblyMass)
	end

	return true
end

function ProjectileEvents:ApplyThrowableRadiusDamage(origin: Vector3, radius: number, explosiveData, owner)
	local partsInRadius = workspace:GetPartBoundsInRadius(origin, radius)
	local isSpread = explosiveData.Type and explosiveData.Type == "Spread"
	task.spawn(function()
		local impulseAppliedList = {}
		for _, obj in partsInRadius do
			-- affect humans only
			self:BodyPartDamage(obj, explosiveData, owner)
			if not isSpread then
				self:ApplyExplosionForce(obj, origin, radius, impulseAppliedList)
			end
		end
	end)
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
	self:ApplyThrowableRadiusDamage(center, 20, throwableData, owner)

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
function ProjectileEvents:GunHitEnvironment(gunData, raycastResult: RaycastResult)
	-- hit environment
	ServerEffectsDisplayer:DisplayProjectileMark(gunData.ProjectileType or "Bullet", raycastResult)
end

function ProjectileEvents:ProjectileHitMaterial(result: RaycastResult)
	local hitCFrame = result.Instance.CFrame
	local material = result.Instance.Material
	if not hitCFrame or not material then
		return
	end
	local data = material and MaterialHitData[material]
	if data then
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			data.HitSound,
			hitCFrame,
			{ Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1 }
		)

		if data.Destroy then
			result.Instance:Destroy()
		end

		if data.HitParticle then
			ServerEffectsDisplayer:DisplayDestroyParticle(data.HitParticle, hitCFrame.Position)
		end
	end
end

function ProjectileEvents:OnProjectileHitReceiveServer(context, result: RaycastResult?)
	-- Hit nothing, the raycast hit the air and the lifetime of the projectile ends, hence nil
	if not result then
		return
	end
	--warn(`OnHit fired by server {result.Instance.Name}`)
	local data = context.UserData
	local projectileType = data.ProjectileType
	-- ON BULLET HIT
	if projectileType == "Bullet" then
		self:ProjectileHitMaterial(result)
		local bulletCosmetic = context.CosmeticBulletObject
		local hitPlayer = ProjectileEvents:GunHitPlayer(data, result, nil, bulletCosmetic)
		if hitPlayer then
			return
		end

		local hitDestroyable = ProjectileEvents:GunHitDestroyable(data, result)
		if hitDestroyable then
			return
		end

		ProjectileEvents:GunHitEnvironment(data, result)

		-- ON THROWABLE IMPACT LAND
	elseif projectileType == "Throwable" then
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
			if data.Class.CurrentAmmo <= 0 and type(data.Class.Destroy) == "function" then
				data.Class:Destroy()
			end
		end)
		-- ON SHRAPNEL HIT
	elseif projectileType == "Shrapnel" then
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
	local cosmeticBullet = context.CosmeticBulletObject

	self:ProjectileHitMaterial(result)

	-- handle hitting player
	if self:FragmentHitPlayer(result, owner, throwableData, cosmeticBullet) then
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
	if not result then
		return
	end
	warn(`OnHit fired by player. Hit object: {result.Instance.Name}`)
	-- GUN PROJECTILES
	if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
		local human = PlayerManager:GetHumanClassFromPlayer(context.UserData.Owner)
		if not human then
			return
		end

		-- Ensure relevant data exists
		local currentGunName = human.Inventory and human.Inventory:GetGun() and human.Inventory:GetGun().Name
		if not currentGunName then
			return
		end

		local gunData = GunData[currentGunName]
		if not gunData then
			warn("GunData missing from OnProjectileHitReceivePlayer")
			return
		end

		-- Custom logic if it hits a specified material
		self:ProjectileHitMaterial(result)

		-- Hit Human class
		local bulletCosmetic = context.CosmeticBulletObject

		local hitPlayer = ProjectileEvents:GunHitPlayer(gunData, result, context.UserData.Owner, bulletCosmetic)
		if hitPlayer then
			return
		end

		-- Hit Destroyable class
		local hitDestroyable = ProjectileEvents:GunHitDestroyable(gunData, result, context.UserData.Owner)
		if hitDestroyable then
			return
		end

	-- THROWABLE PROJECTILES
	elseif CollectionService:HasTag(context.CosmeticBulletObject, "Throwable") then
		local human = PlayerManager:GetHumanClassFromPlayer(context.UserData.Owner)

		if not human then
			return
		end

		local currentThrowable = human.Inventory and human.Inventory:GetThrowable()
		if not currentThrowable then
			warn("CurrentThrowable not valid")
			return
		end

		local throwableName = currentThrowable.Name
		if not throwableName then
			return
		end

		local throwableData = ThrowableData[throwableName]
		if not throwableData then
			warn("ThrowableData missing for: " .. tostring(throwableName))
			return
		end

		ServerSoundHandler:Play3DOneShotToOthers(nil, throwableData.LandSound, result.Instance.CFrame)

		-- Destroy visual grenade after x seconds
		if context.CosmeticBulletObject then
			Debris:AddItem(context.CosmeticBulletObject, throwableData.DetonationTime)
		end

		if currentThrowable.CurrentAmmo <= 0 then
			human.Inventory:RemoveWeapon("Throwable")
		end

		-- Detonates grenade after specified detonation time and spawns visuals and fragments.
		task.delay(throwableData.DetonationTime, function()
			-- Re-validate after delay, player may have left by now
			if not result then
				return
			end
			local hitPos = result.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				throwableData.DetonationSound,
				result.Instance.CFrame,
				{ MaxDistance = 150 }
			)
			self:OnThrowImpact(throwableData.ImpactParticle, hitPos)
			self:SpawnFragments(result, context.UserData.Owner, throwableData)
		end)
	end
end

function ProjectileEvents:Initialize()
	ProjectileContext.VetraSignals.OnPierce:Connect(function(context, result, velocity, pierceCount: number)
		print("OnPierce fired")
		self:ProjectileHitMaterial(result)
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
