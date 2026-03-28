local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ThrowableSignals = require(script.Parent.ThrowableSignals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Effects = ReplicatedStorage.Shared.Effects
local Throwable = {}
type Human = ClassTypes.Human
Throwable.__index = Throwable

local fragmentParam = RaycastParams.new()
fragmentParam.FilterType = Enum.RaycastFilterType.Exclude

function Throwable.new(throwableName: string, humanRef: Human?)
	assert(ThrowableData[throwableName], "Throwable name missing, cannot initialize")
	--assert(humanRef, "Human reference missing from throwable class")
	local self = setmetatable({}, Throwable)
	local throwableData = ThrowableData[throwableName]
	self.Owner = humanRef
	self.Tool = nil

	self.Name = throwableName
	self.Type = throwableData.Type
	self.CurrentAmmo = throwableData.MaxAmmo
	self.DetonationTime = throwableData.DetonationTime
	self.FragmentCount = throwableData.FragmentCount
	self.FragmentRange = throwableData.FragmentRange
	self.FragmentDamage = throwableData.Damage
	self.FragmentType = throwableData.Type
	self.ThrowDelay = throwableData.ThrowDelay
	self.Damage = throwableData.Damage
	self.Velocity = throwableData.Velocity
	self.ImpactParticle = throwableData.ImpactParticle
	self.SpreadParticle = throwableData.SpreadParticle
	self.SpreadDuration = throwableData.SpreadDuration

	self.ThrowForce = nil
	self.CanThrow = true
	self.Janitor = Janitor.new()

	self.FastCast = FastCast.new()
	self.ThrowVelocity = throwableData.Velocity
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.CosmeticBulletTemplate = nil
	self.ProjectileData.CosmeticBulletContainer = workspace.ProjectilesFolder
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { self.Tool }
	self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	self.ProjectileData.AutoIgnoreContainer = true

	self:ConnectProjectileEvents()
	return self
end

function Throwable:Throw(cameraLookVector: Vector3)
	if not self.CanThrow then
		return false
	end
	self.CanThrow = false
	self.Tool.Handle.Transparency = 1
	self.CurrentAmmo = math.max(0, self.CurrentAmmo - 1)
	local rightHand = self.Owner.BodyParts["RightHand"]
	self.FastCast:Fire(rightHand.CFrame.Position, cameraLookVector, self.ThrowVelocity, self.ProjectileData)

	if self.CurrentAmmo == 0 then
		self:Remove()
	end

	task.delay(ThrowableData[self.Name].ThrowDelay, function()
		self.CanThrow = true

		if self.Tool and self.Tool:FindFirstChild("Handle") then
			self.Tool.Handle.Transparency = 0
		end
	end)

	return true
end

function Throwable:FragmentHitPlayer(hit: RaycastResult)
	-- damage bodyparts if hits player
	local isModel = hit.Instance:FindFirstAncestorOfClass("Model")
	if isModel then
		local humanoid = isModel:FindFirstChild("Humanoid")
		if humanoid then
			if self.FragmentType == "Explosive" then
				GunSignals.PlayerHit:Fire(hit, humanoid, self.FragmentDamage, self.Tool.Handle.Position)
			elseif self.FragmentType == "Spread" then
				GunSignals.InflictLimbDamage:Fire(
					hit.Instance,
					self.Damage,
					self.SpreadParticle,
					self.SpreadDuration,
					humanoid
				)
			end
		end
	end
end

function Throwable:FragmentHitDestroyable(hit: RaycastResult)
	-- damage bodyparts if hits player
	local instance = hit.Instance
	local isDestroyable = CollectionService:HasTag(instance, "Destroyable")
	if isDestroyable then
		local destroyableClass = DestroyableManager:GetDestroyable(instance)
		if not destroyableClass then
			warn("[FragmentHitDestroyable] Destroyable class is not valid?")
			return
		end

		if self.Type == "Explosive" then
			destroyableClass:Damage(self.Damage)
		end
	end
end

function Throwable:SpawnFragments(spawnPos: Vector3)
	for _ = 1, self.FragmentCount do
		local dir = RandomModule.GetNextUnitVector()

		local hit = workspace:Raycast(spawnPos, dir * self.FragmentRange)

		-- if fragment hits something damagable, it should apply damage and cease to exist
		if hit then
			local hitInstance = hit.Instance
			if hitInstance:FindFirstAncestorOfClass("Accessory") then
				continue
			end
			-- handle hitting player
			if self:FragmentHitPlayer(hit) then
				continue
			end

			-- handle hitting destroyables
			if self:FragmentHitDestroyable(hit) then
				continue
			end
		end

		--debug rays
		-- local debugPart = Instance.new("Part")
		-- debugPart.CanCollide = false
		-- debugPart.CanTouch = false
		-- debugPart.CanQuery = false
		-- debugPart.CFrame = CFrame.lookAt(spawnPos, spawnPos + dir) * CFrame.new(0, 0, -fragmentRange / 2)
		-- debugPart.Size = Vector3.new(0.1, 0.1, fragmentRange)
		-- debugPart.Parent = workspace
	end
end

function Throwable:OnThrowImpact(cosmeticBulletObj)
	-- get particle name
	local throwEffect = self.ImpactParticle
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
	explosion.Position = cosmeticBulletObj.Position + Vector3.new(0, 1, 0)
	effect.Parent = explosion
	effect.Enabled = true
	cosmeticBulletObj:Destroy()

	Debris:AddItem(explosion, 1)
end

function Throwable:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _, cosmeticBulletObj)
		cosmeticBulletObj.Anchored = false

		ServerSoundHandler:Play3DOneShotToOthers(nil, ThrowableData[self.Name].LandSound, cosmeticBulletObj.CFrame)
		task.delay(self.DetonationTime, function()
			local cosmeticPos = cosmeticBulletObj.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				ThrowableData[self.Name].DetonationSound,
				cosmeticBulletObj.CFrame,
				{ MaxDistance = 150 }
			)

			self:OnThrowImpact(cosmeticBulletObj)
			self:SpawnFragments(cosmeticPos + Vector3.new(0, 1, 0))
		end)
	end))

	self.Janitor:Add(
		self.FastCast.LengthChanged:Connect(
			function(activeCast, lastPoint, rayDir, displacement, segmentVelocity, cosmeticBulletObj)
				local newPos = lastPoint + (rayDir * displacement)
				cosmeticBulletObj.Position = newPos
			end
		)
	)
end

function Throwable:Remove()
	if self.Owner.HumanType == "Player" then
		local toolInInventory = self.Owner.Player.Backpack:FindFirstChild(self.Name)
		local toolInHands = Utility.GetInstance(self.Owner.Player.Character, false, self.Name)
		if toolInInventory then
			toolInInventory:Destroy()
			return
		end

		if toolInHands then
			toolInHands:Destroy()
		end
	else
		-- HumanNPC
		self.Owner:UnEquipCurrentTool()
	end
end

function Throwable:AddThrowableToInventory()
	local clone: Tool = ServerStorage.Templates:FindFirstChild(self.Name):Clone()
	self.Tool = clone

	clone.Parent = if self.Owner.HumanType == "Player" then self.Owner.Player.Backpack else self.Character
	self.Janitor:Add(self.Tool)

	local projectileClone = self.Tool.Handle:Clone()
	projectileClone.Anchored = true

	self.ProjectileData.CosmeticBulletTemplate = projectileClone

	if self.Owner.HumanType == "Player" then
		ThrowableSignals.ConnectThrowableSignal:Fire(self.Owner.Player, clone)
	end
end
return Throwable
