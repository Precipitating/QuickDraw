local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ProjectileContext = require(script.Parent.ProjectileContext)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Effects = ReplicatedStorage.Shared.Effects
local ProjectileEvents = {}

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
	-- damage bodyparts if hits player
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
		end
	end
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
	end
end

function ProjectileEvents:SpawnFragments(spawnPos: Vector3, owner, throwableData)
	for _ = 1, throwableData.FragmentCount do
		local dir = RandomModule.GetNextUnitVector()

		local hit = workspace:Raycast(spawnPos, dir * throwableData.FragmentRange)

		-- if fragment hits something damagable, it should apply damage and cease to exist
		if hit then
			local hitInstance = hit.Instance
			if hitInstance:FindFirstAncestorOfClass("Accessory") then
				continue
			end
			-- handle hitting player
			if self:FragmentHitPlayer(hit, owner, throwableData) then
				continue
			end

			-- handle hitting destroyables
			if self:FragmentHitDestroyable(hit, throwableData) then
				continue
			end
		end

		--debug rays
		-- local debugPart = Instance.new("Part")
		-- debugPart.CanCollide = false
		-- debugPart.CanTouch = false
		-- debugPart.CanQuery = false
		-- debugPart.CFrame = CFrame.lookAt(spawnPos, spawnPos + dir) * CFrame.new(0, 0, -throwableData.FragmentRange / 2)
		-- debugPart.Size = Vector3.new(0.1, 0.1, throwableData.FragmentRange)
		-- debugPart.Parent = workspace
	end
end

function ProjectileEvents:OnThrowImpact(landPos: Vector3, impactParticleName: string)
	-- get particle name
	local throwEffect = impactParticleName
	-- clone particle if valid
	local effect = if Effects[throwEffect] then Effects[throwEffect]:Clone() else nil

	if not effect then
		warn("[Throwable:OnThrowImpact] Effect not valid to spawn")
		return
	end

	local explosion: Part = Instance.new("Part")
	explosion.Parent = workspace
	explosion.CanCollide = false
	explosion.CanQuery = false
	explosion.Transparency = 1
	explosion.Anchored = true
	explosion.Position = landPos + Vector3.new(0, 1, 0)
	effect.Parent = explosion
	effect.Enabled = true

	Debris:AddItem(explosion, 1)
end

-- This should be executed last, as every other option should be exhausted before deciding we've hit
-- the environment.
function ProjectileEvents:GunHitEnvironment(raycastResult: RaycastResult)
	-- hit environment
	local hitPos = CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
	GunSignals.DisplayBulletHole:Fire(hitPos)
end

function ProjectileEvents:OnProjectileHitReceiveServer(context, result: RaycastResult?)
	-- Hit nothing, the raycast hit the air and the lifetime of the projectile ends, hence nil
	if not result then
		return
	end
	print(`OnHit fired by server {result.Instance.Name}`)

	-- GUN PROJECTILES
	if context.UserData.ProjectileType == "Bullet" then
		local hitPlayer = ProjectileEvents:GunHitPlayer(context.UserData, result)
		if hitPlayer then
			return
		end

		local hitDestroyable = ProjectileEvents:GunHitDestroyable(context.UserData, result)
		if hitDestroyable then
			return
		end

		ProjectileEvents:GunHitEnvironment(result)

		-- THROWABLE PROJECTILES
	elseif context.UserData.ProjectileType == "Throwable" then
		local data = context.UserData
		local throwableData = data.Data
		ServerSoundHandler:Play3DOneShotToOthers(nil, throwableData.LandSound, result.Instance.CFrame)
		task.delay(throwableData.DetonationTime, function()
			if context.CosmeticBulletObject then
				context.CosmeticBulletObject:Destroy()
			end
			local hitPos = result.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				throwableData.DetonationSound,
				result.Instance.CFrame,
				{ MaxDistance = 150 }
			)

			self:OnThrowImpact(hitPos, throwableData.ImpactParticle)
			self:SpawnFragments(hitPos + Vector3.new(0, 1, 0), data.Class.Owner, throwableData)
			if data.Class.CurrentAmmo <= 0 then
				data.Class:Destroy()
			end
		end)
	end
end

function ProjectileEvents:OnProjectileHitReceivePlayer(context, result: RaycastResult?)
	-- Hit nothing, the raycast hit the air and the lifetime of the projectile ends, hence nil
	if not result then
		return
	end
	print(`OnHit fired by player {result.Instance.Name}`)

	-- GUN PROJECTILES
	if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
		local human = PlayerManager:GetHumanClassFromPlayer(context.UserData.Owner)
		local currentGunName = human.CurrentGun and human.CurrentGun.GunName
		if not currentGunName then
			return
		end
		self:PlayerReduceAmmo(context.UserData.Owner)
		local gunData = GunData[currentGunName]
		if not gunData then
			warn("Gundata missing from OnProjectileHitReceivePlayer")
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
		task.delay(throwableData.DetonationTime, function()
			if context.CosmeticBulletObject then
				context.CosmeticBulletObject:Destroy()
			end
			local hitPos = result.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				throwableData.DetonationSound,
				result.Instance.CFrame,
				{ MaxDistance = 150 }
			)

			self:OnThrowImpact(hitPos, throwableData.ImpactParticle)
			self:SpawnFragments(hitPos + Vector3.new(0, 1, 0), data.Owner, throwableData)

			if throwable.CurrentAmmo <= 0 then
				throwable:Destroy()
			end
		end)
	end
end

function ProjectileEvents:PlayerReduceAmmo(player: Player)
	-- deduct ammo
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	local gunClass = human.CurrentGun
	gunClass:UpdateAmmo(-1)
end

function ProjectileEvents:Initialize()
	ProjectileContext.VetraSignals.OnPierce:Connect(function(context, result, velocity, pierceCount: number)
		print("OnPierce fired")
	end)

	ProjectileContext.Net.OnFireRejected:Connect(function(player, reason)
		warn(`Rejected projectile hit because of {reason}`)
	end)

	-- for NPCS/Server
	ProjectileContext.VetraSignals.OnHit:Connect(function(context, result, velocity)
		if context.UserData.Owner and context.UserData.Owner:IsA("Player") then
			return
		end
		self:OnProjectileHitReceiveServer(context, result)
	end)

	-- players firing from client
	ProjectileContext.Net.OnValidatedHit:Connect(function(player, context, result, velocity, impactForce)
		context.UserData["Owner"] = player
		self:OnProjectileHitReceivePlayer(context, result)
	end)
end

return ProjectileEvents
