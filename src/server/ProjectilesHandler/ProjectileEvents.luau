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
local LightweightNpcsServerAPI = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerScreenEffects = require(ServerScriptService.Server.ServerScreenEffects)
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
local ProjectileRaycastParam = RaycastParams.new()
ProjectileRaycastParam.CollisionGroup = "Projectile"
local function GetHumanoidFromHit(instance: Instance): Humanoid?
	local model = instance and (instance:IsA("Model") or instance:FindFirstAncestorOfClass("Model"))
	if not model then
		return nil
	end

	local humanoid = instance:FindFirstChild("Humanoid")

	if not humanoid then
		return nil
	end

	return humanoid
end

function ProjectileEvents:GunHitPlayer(hitData, context, raycastResult: RaycastResult)
	local parent = raycastResult.Instance.Parent
	if not parent then
		return false
	end

	local hitHumanoid = GetHumanoidFromHit(parent)
	local isNPC = parent:GetAttribute("npcId")

	if not hitHumanoid and not isNPC then
		return false
	end

	if not CollectionService:HasTag(parent, "NPC") and not CollectionService:HasTag(parent, "Player") then
		return false
	end

	local owner = context.UserData.Owner
	local cosmeticBullet = context.CosmeticBulletObject

	-- hit body part
	GunSignals.PlayerHit:Fire(
		raycastResult,
		hitHumanoid or isNPC,
		hitData.Damage,
		cosmeticBullet,
		owner or hitData.Owner
	)
	print(`{raycastResult.Instance.Name} hit!`)
	return true
end

function ProjectileEvents:GunHitAnimal(gunData, context, raycastResult: RaycastResult?)
	if not gunData or not raycastResult then
		return false
	end
	local hitInstance = raycastResult.Instance
	local parent = hitInstance.Parent
	local owner = context.UserData.Owner

	if not parent then
		return false
	end

	if not CollectionService:HasTag(parent, "Animal") then
		return false
	end
	GunSignals.AnimalHit:Fire(gunData, raycastResult, owner)

	return true
end

function ProjectileEvents:GunHitDestroyable(hitData, context, raycastResult: RaycastResult)
	local instance = raycastResult.Instance
	local destroyableClass: Destroyable = DestroyableManager.Destroyables[instance]
	if not destroyableClass then
		return
	end

	local owner = context.UserData.Owner

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
	local isPlayer = character:FindFirstChild("Humanoid")
	local isNPC = character:GetAttribute("npcId")

	if not isPlayer and not isNPC then
		return
	end

	local hitPlayer = if isPlayer
		then Players:GetPlayerFromCharacter(character)
		else LightweightNpcsServerAPI:GetNpcById(isNPC)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Redirect to the replicated storage NPC model if hits NPC for auto replication
	if isNPC then
		limbPart = hitPlayer.instance:FindFirstChild(limbPart.Name)

		if not limbPart then
			return
		end
	end

	if limbPart:FindFirstChildOfClass("RopeConstraint") then
		return
	end

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

	if isPlayer and hitPlayer then
		HumanNetwork:ToggleBackpackVisibility(hitPlayer, false, true)
	end

	-- ─────────────── Attachments ───────────────

	if not anchorPos then
		return
	end
	local limbAttach = Instance.new("Attachment")
	limbAttach.Parent = limbPart
	--limbAttach.WorldPosition = hit.Position

	local endAttach = Instance.new("Attachment")
	endAttach.Parent = anchorInstance
	--endAttach.WorldPosition = anchorPos

	-- ── Rope ─────────────────────────────────────────────────────────────

	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = endAttach
	rope.Attachment1 = limbAttach
	rope.Length = (hit.Position - anchorPos).Magnitude
	rope.Restitution = 0
	rope.Visible = true
	rope.Thickness = 0.2
	rope.Parent = limbPart

	if isNPC then
		hitPlayer.onRagdoll:Fire(duration)
	end

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
		if hitPlayer and isPlayer then
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

-- Determine humanoid type, animal or human or any future humanoid types
function ProjectileEvents:GetHumanoidType(parent)
	local humanoidType = nil
	if CollectionService:HasTag(parent, "Player") or CollectionService:HasTag(parent, "NPC") then
		humanoidType = "Human"
	elseif CollectionService:HasTag(parent, "Animal") then
		humanoidType = "Animal"
	end

	return humanoidType
end

function ProjectileEvents:FragmentHitHumanoid(raycastResult: RaycastResult, context)
	if not raycastResult.Instance then
		return false
	end
	local isModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
	if not isModel then
		return false
	end
	local humanoid = isModel:FindFirstChild("Humanoid")
	if not humanoid then
		return false
	end

	local humanoidType = self:GetHumanoidType(isModel)
	if not humanoidType then
		return false
	end

	local throwableData = context.UserData.Data
	local owner = context.UserData.Owner
	local cosmeticBullet = context.CosmeticBulletObject

	local isPlayer = if owner and typeof(owner) == "table" then owner.Character else owner

	if throwableData.Type == "Explosive" then
		if humanoidType == "Human" then
			GunSignals.PlayerHit:Fire(raycastResult, humanoid, throwableData.Damage, cosmeticBullet, isPlayer, true)
		elseif humanoidType == "Animal" then
			GunSignals.AnimalHit:Fire(throwableData, raycastResult, isPlayer)
		end
	elseif throwableData.Type == "Status" then
		GunSignals.ApplyLimbStatusDamage:Fire(
			throwableData.SpreadParticle,
			throwableData.SpreadDuration,
			throwableData.Damage,
			raycastResult.Instance,
			humanoid,
			isPlayer,
			humanoidType,
			true
		)
	end
	-- special effects add-on
	task.spawn(function()
		if throwableData.Subtype and throwableData.SubtypeEffectDuration then
			self:HandleSubTypes(throwableData.Subtype, throwableData.SubtypeEffectDuration, raycastResult)
		end
	end)
	return true
end
local function RandomConeDirection(BaseDirection: vector, HalfAngleDeg: number): vector
	local HalfAngleRad = math_rad(HalfAngleDeg)
	local Phi = RandomModule.GetRandomDecimalBetween(0, math.pi * 2)
	local CosTheta = RandomModule.GetRandomDecimalBetween(math_cos(HalfAngleRad), 1)
	local SinTheta = math_sqrt(1 - CosTheta * CosTheta)

	-- Pick a non-parallel arbitrary reference vector
	local arbitrary = math_abs(BaseDirection.x) < 0.9 and vector.create(1, 0, 0) or vector.create(0, 1, 0)

	-- BOTH orthogonal basis vectors MUST be normalized
	local PerpendicularA = vector.normalize(vector.cross(BaseDirection, arbitrary))
	local PerpendicularB = vector.normalize(vector.cross(BaseDirection, PerpendicularA))

	local ConeVector = BaseDirection * CosTheta
		+ PerpendicularA * (SinTheta * math_cos(Phi))
		+ PerpendicularB * (SinTheta * math_sin(Phi))

	return vector.normalize(ConeVector)
end
function ProjectileEvents:FragmentHitDestroyable(hit: RaycastResult, context)
	-- damage bodyparts if hits player
	local instance = hit.Instance
	local isDestroyable = CollectionService:HasTag(instance, "Destroyable")
	if isDestroyable then
		local destroyableClass = DestroyableManager:GetDestroyable(instance)
		if not destroyableClass then
			warn("[FragmentHitDestroyable] Destroyable class is not valid?")
			return
		end

		local throwableData = context.UserData.Data

		if throwableData.Type == "Explosive" then
			destroyableClass:Damage(throwableData.Damage)
		end

		return true
	end

	return false
end

function ProjectileEvents:FragmentHitHumanNPC(hit: RaycastResult, context)
	local partHit = hit and hit.Instance
	if not partHit then
		return false
	end

	local parent = partHit.Parent

	if not parent then
		return false
	end

	local npcId = parent:GetAttribute("npcId")
	if not npcId then
		return false
	end

	local npcRecord = LightweightNpcsServerAPI:GetNpcById(npcId)

	if not npcRecord then
		return false
	end

	local attacker = context.UserData.Owner
	local throwableData = context.UserData.Data
	local cosmeticBullet = context.CosmeticBulletObject

	local isPlayer = if attacker and typeof(attacker) == "table" then attacker.Character else attacker

	if throwableData.Type == "Explosive" then
		GunSignals.PlayerHit:Fire(hit, npcId, throwableData.Damage, cosmeticBullet, isPlayer, true)
	elseif throwableData.Type == "Status" then
		GunSignals.ApplyLimbStatusDamage:Fire(
			throwableData.SpreadParticle,
			throwableData.SpreadDuration,
			throwableData.Damage,
			hit.Instance,
			npcId,
			isPlayer,
			"Human",
			true
		)
	end

	-- 	-- special effects add-on
	task.spawn(function()
		if throwableData.Subtype and throwableData.SubtypeEffectDuration then
			self:HandleSubTypes(throwableData.Subtype, throwableData.SubtypeEffectDuration, hit)
		end
	end)

	return true
end

function ProjectileEvents:FragmentHitEnvironment(hit: RaycastResult, context)
	local throwableData = context.UserData.Data
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
	elseif explosiveType == "Status" then
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
	local npcId = parent:GetAttribute("npcId")
	local isBodyPart = damagedObject:IsA("MeshPart") and (humanoid or npcId)
	local humanoidType = self:GetHumanoidType(parent)

	local dmg = explosiveData.BaseDamage or explosiveData.Damage
	local effectDuration = explosiveData.SpreadDuration or 0
	local damageType = explosiveData.HumanEffect or explosiveData.Type
	if isBodyPart then
		if damageType == "Status" then
			GunSignals.ApplyLimbStatusDamage:Fire(
				explosiveData.SpreadParticle,
				effectDuration,
				dmg,
				damagedObject,
				humanoid or npcId,
				initiator,
				humanoidType,
				true
			)
		else
			if damageType == "Damage" then
				GunSignals.ApplyLimbStatusDamage:Fire(
					nil,
					1,
					dmg,
					damagedObject,
					humanoid or npcId,
					initiator,
					humanoidType,
					true
				)
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
		direction = vector.create(0, 1, 0) -- Safe fallback if center is identical to root
	else
		-- Normalize the actual direction, then blend in a slight upward trajectory
		direction = (direction.Unit + vector.create(0, 0.5, 0)).Unit
	end

	if humanClass.ApplyImpulse then
		humanClass:ApplyImpulse(direction * force * target.AssemblyMass)
	end

	return true
end

function ProjectileEvents:ApplyThrowableRadiusDamage(origin: Vector3, radius: number, explosiveData, owner)
	local partsInRadius = workspace:GetPartBoundsInRadius(origin, radius)
	local isSpread = explosiveData.Type and explosiveData.Type == "Status"
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

function ProjectileEvents:ApplyThrowableScreenEffect(position: Vector3, radius: number)
	local playersInRadius = workspace:GetPartBoundsInRadius(position, radius)

	task.spawn(function()
		for _, obj in playersInRadius do
			if not obj.Parent then
				continue
			end
			local isPlayer = Players:GetPlayerFromCharacter(obj.Parent)

			if not isPlayer then
				continue
			end

			ServerScreenEffects:ApplyOneShotEffect(isPlayer, "Explosion")
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

	-- explosion screen shake effect
	self:ApplyThrowableScreenEffect(raycastResult.Position, 40)

	-- apply radius damage first, for guaranteed damage within it
	self:ApplyThrowableRadiusDamage(center, 20, throwableData, owner)

	-- spawn fragments on surface outwards from the radius
	for _ = 1, throwableData.FragmentCount do
		local randomDir = RandomConeDirection(vector.create(0, 1, 0), 180)

		local surfaceResult = workspace:Raycast(center, randomDir * blastRadius)
		local origin = if surfaceResult then surfaceResult.Position else center + randomDir * blastRadius

		local context = ProjectileContext.BulletContext.new({
			Origin = origin,
			Direction = randomDir,
			Speed = 200,
			RaycastParams = ProjectileRaycastParam,
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
			hitCFrame.Position,
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

function ProjectileEvents:OnFragmentHit(context, result: RaycastResult?)
	-- if fragment hits something damagable, it should apply damage and cease to exist
	if not result then
		return
	end
	self:ProjectileHitMaterial(result)

	if self:FragmentHitHumanNPC(result, context) then
		return
	end

	-- handle hitting player/animal
	if self:FragmentHitHumanoid(result, context) then
		return
	end

	-- handle hitting destroyables
	if self:FragmentHitDestroyable(result, context) then
		return
	end

	-- else hit environment
	self:FragmentHitEnvironment(result, context)
end
-- Resolves the current gun's GunData for a player owner.
function ProjectileEvents:GetGunDataForOwner(owner: Player)
	local human = PlayerManager:GetHumanClassFromPlayer(owner)
	if not human then
		return nil
	end

	local gun = human.Inventory and human.Inventory:GetGun()
	local gunName = gun and gun.Name
	if not gunName then
		return nil
	end

	local gunData = GunData[gunName]
	if not gunData then
		warn("GunData missing from OnProjectileHitReceivePlayer")
		return nil
	end

	return gunData
end

-- Resolves the current throwable's ThrowableData/instance/human for a player owner.
function ProjectileEvents:GetThrowableDataForOwner(owner: Player)
	local human = PlayerManager:GetHumanClassFromPlayer(owner)
	if not human then
		return nil
	end

	local currentThrowable = human.Inventory and human.Inventory:GetThrowable()
	if not currentThrowable then
		warn("CurrentThrowable not valid")
		return nil
	end

	local throwableData = ThrowableData[currentThrowable.Name]
	if not throwableData then
		warn("ThrowableData missing for: " .. tostring(currentThrowable.Name))
		return nil
	end

	return throwableData, currentThrowable, human
end

-- Shared bullet resolution: material fx, then player/animal/destroyable (and optionally environment).
function ProjectileEvents:ResolveBulletHit(gunData, context, result: RaycastResult, checkEnvironment: boolean?)
	self:ProjectileHitMaterial(result)

	if self:GunHitPlayer(gunData, context, result) then
		return true
	end
	if self:GunHitAnimal(gunData, context, result) then
		return true
	end
	if self:GunHitDestroyable(gunData, context, result) then
		return true
	end
	if checkEnvironment then
		self:GunHitEnvironment(gunData, result)
	end

	return false
end

-- Shared "grenade lands, then detonates after DetonationTime" flow.
-- onDetonate(hitPos) runs caller-specific cleanup right before fragments spawn.
function ProjectileEvents:HandleThrowableLanding(
	throwableData,
	result: RaycastResult,
	owner: Player?,
	onDetonate: (Vector3) -> ()
)
	ServerSoundHandler:Play3DOneShotToOthers(nil, throwableData.LandSound, result.Position)

	task.delay(throwableData.DetonationTime, function()
		local hitPos = result.Position
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			throwableData.DetonationSound,
			result.Position,
			{ MaxDistance = 150 }
		)

		if onDetonate then
			onDetonate(hitPos)
		end

		self:SpawnFragments(result, owner, throwableData)
	end)
end

function ProjectileEvents:OnProjectileHitReceivePlayer(context, result: RaycastResult?)
	if not result then
		return
	end
	warn(`OnHit fired by player. Hit object: {result.Instance.Name}`)

	local owner = context.UserData.Owner
	local cosmeticBullet = context.CosmeticBulletObject

	if CollectionService:HasTag(cosmeticBullet, "Bullet") then
		local gunData = self:GetGunDataForOwner(owner)
		if not gunData then
			return
		end
		self:ResolveBulletHit(gunData, context, result)
	elseif CollectionService:HasTag(cosmeticBullet, "Throwable") then
		local throwableData, currentThrowable, human = self:GetThrowableDataForOwner(owner)
		if not throwableData then
			return
		end

		if cosmeticBullet then
			task.delay(throwableData.DetonationTime, function()
				if cosmeticBullet then
					cosmeticBullet:Destroy()
				end
			end)
		end
		if currentThrowable.CurrentAmmo <= 0 then
			human.Inventory:RemoveWeapon("Throwable")
		end

		self:HandleThrowableLanding(throwableData, result, owner, function(hitPos)
			self:OnThrowImpact(throwableData.ImpactParticle, hitPos)
			if cosmeticBullet then
				cosmeticBullet:Destroy()
			end
		end)
	end
end

function ProjectileEvents:OnProjectileHitReceiveServer(context, result: RaycastResult?)
	if not result or not result.Instance then
		return
	end

	local data = context.UserData
	local cosmeticBullet = context.CosmeticBulletObject

	if data.ProjectileType == "Bullet" then
		self:ResolveBulletHit(data, context, result, true)
	elseif data.ProjectileType == "Throwable" then
		local throwableData = data.Data

		self:HandleThrowableLanding(throwableData, result, data.Class.Owner, function(hitPos)
			if cosmeticBullet then
				cosmeticBullet:Destroy()
			end
			ServerEffectsDisplayer:DisplayDestroyParticle(throwableData.ImpactParticle, hitPos)

			local class = data.Class
			if class and class.CurrentAmmo and type(class.Destroy) == "function" and class.CurrentAmmo <= 0 then
				class:Destroy()
			end
		end)
	elseif data.ProjectileType == "Shrapnel" then
		self:OnFragmentHit(context, result)
	end
end

local function ApplyBulletsWhizz(context)
	local innerContext = context.Context
	local bulletDirection = innerContext.Direction -- Pre-calculated unit vector
	local currentPosition = context.Position
	local bulletOwner = innerContext.UserData.Owner

	-- Derive lastPosition by backing up one frame step using Velocity and DeltaTime
	local lastPosition = currentPosition - (context.Velocity * innerContext.SimulationTime)
	local displacement = currentPosition - lastPosition
	local segmentLength = displacement.Magnitude

	if segmentLength <= 0 then
		return
	end

	-- Initialize a table in UserData to remember who we already whistled for
	if not innerContext.UserData.WhistledPlayers then
		innerContext.UserData.WhistledPlayers = {}
	end
	local whistled = innerContext.UserData.WhistledPlayers

	for _, player in Players:GetPlayers() do
		-- Skip if this specific bullet already whistled for this player
		if whistled[player.UserId] then
			continue
		end

		if bulletOwner and bulletOwner == player then
			continue
		end

		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head then
			continue
		end

		local headPos = head.Position
		local relativeVector = headPos - lastPosition

		-- BOUNDARY CHECK: Project the head onto the bullet path segment
		local dotProjection = relativeVector:Dot(bulletDirection)

		-- If the closest approach point falls exactly within this frame's segment length...
		if dotProjection >= 0 and dotProjection <= segmentLength then
			-- Calculate the exact perpendicular miss distance (perpendicular line)
			local closestPathPoint = lastPosition + (bulletDirection * dotProjection)
			local exactMissDistance = (closestPathPoint - headPos).Magnitude

			-- Trigger condition
			if exactMissDistance >= 1 and exactMissDistance <= 3 then
				-- Mark as whistled instantly so it never spams again for this bullet
				whistled[player.UserId] = true

				ServerSoundHandler:Play3DOneShotToOthers(
					nil,
					"BulletMiss",
					closestPathPoint,
					{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
				)
				warn("Whizzed past " .. player.Name .. " once!")
			end
		end
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

	ProjectileContext.VetraSignals.OnSegmentOpen:Connect(function(context, segment)
		local serverProjectile = context.CosmeticBulletObject
		local owner = context.UserData.Owner
		if serverProjectile then
			if owner and owner:HasTag("NPC") then
				return
			end
			serverProjectile.Transparency = 1
		end
	end)

	-- for NPCS/Server
	ProjectileContext.VetraSignals.OnHit:Connect(function(context, result, velocity)
		if not result or not result.Instance then
			return
		end
		local owner = context.UserData.Owner
		if owner and typeof(owner) == "Instance" and owner:IsA("Player") then
			if context.UserData.ProjectileType ~= "Shrapnel" then
				return
			end
		end
		self:OnProjectileHitReceiveServer(context, result)
	end)

	ProjectileContext.VetraSignals.OnTravelBatch:Connect(function(contexts)
		for _, context in contexts do
			ApplyBulletsWhizz(context)
		end
	end)

	-- players firing from client
	ProjectileContext.Net.OnValidatedHit:Connect(function(player, context, result, velocity, impactForce)
		if not result or not result.Instance then
			warn(`Client shot didn't hit anything`)
			return
		end
		self:OnProjectileHitReceivePlayer(context, result)
	end)
end

return ProjectileEvents
