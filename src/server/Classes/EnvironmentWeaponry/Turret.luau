local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local OVERLAP_LIST_UPDATE_INTERVAL = 5
local Turret = {}

Turret.__index = Turret

function Turret.new(modelRef: Model?)
	local self = setmetatable({}, Turret)
	if not modelRef then
		warn("Turret cannot be initialized! missing model argument!")
		return
	end
	self.Janitor = Janitor.new()
	self.Model = modelRef
	self.Type = modelRef:GetAttribute("Type")
	--
	self.WeaponData = GunData[self.Type]
	if not self.WeaponData then
		warn("Wrong weapon data for Turret, check if its in GunData & correct name")
		return
	end

	self.RadiusPart = Utility.GetInstance(modelRef, false, "Radius").Value
	if not self.RadiusPart then
		warn("Radius not defined for turret, check its object value")
		return
	end
	--
	self.GunType = self.WeaponData.GunType
	self.ShotDelay = self.WeaponData.ShotDelay
	self.ProjectileData = self.WeaponData.ProjectileData
	self.ScanInterval = 0.1
	self.LastUpdatedOverlap = 0
	self.State = "Idle"
	self.Active = true
	self.LastShot = 0
	self.MaxSpreadDeg = 10
	self.LastScanned = 0
	self.TargetTags = { "Player", "NPC" }
	self.CurrentTarget = nil
	self.ShootPoint = modelRef:FindFirstChild("ShootPoint")
	self.MuzzleFlash = modelRef:FindFirstChild("MuzzleFlash")
	self.MuzzleFlashEffects = self.MuzzleFlash and self.MuzzleFlash:FindFirstChildOfClass("Attachment")
	self.TurnSpeed = 5
	self.OverlapParams = OverlapParams.new()
	self.ShootRaycastParams = RaycastParams.new()
	self.ShootRaycastParams.ExcludeInstances = { modelRef }
	return self
end

function Turret:UpdateOverlapParams()
	local formattedTags = {}
	for _, tag in self.TargetTags do
		table.insert(formattedTags, `.{tag}`)
	end

	local cssSelector = table.concat(formattedTags, ", ")

	-- Safe from duplicates
	local finalQuery = `:not(:not({cssSelector}))`

	self.OverlapParams.IncludeInstances = workspace:QueryDescendants(finalQuery)
end

function Turret:AddEnemyTag(tag: string)
	table.insert(self.TargetTags, tag)
end

function Turret:ApplySpread(origin, targetPosition, maxSpreadDegrees)
	local distance = (targetPosition - origin).Magnitude

	-- 1. Create a CFrame pointing straight at the target
	local flatLook = CFrame.lookAt(origin, targetPosition)

	-- 2. Generate a random offset using degrees converted to radians
	local spreadRad = math.rad(maxSpreadDegrees)
	local randomX = RandomModule.GetRandomIntBetween(-100, 100) / 100 * spreadRad
	local randomY = RandomModule.GetRandomIntBetween(-100, 100) / 100 * spreadRad

	-- 3. Use the lookCFrame's RightVector and UpVector to apply the spread
	local spreadDirection = (flatLook.LookVector + (flatLook.RightVector * randomX) + (flatLook.UpVector * randomY)).Unit

	-- 4. Shoot the vector out to the original distance
	return origin + (spreadDirection * distance)
end

function Turret:PredictTargetPosition()
	if not self.CurrentTarget then
		return
	end
	local target = self.CurrentTarget
	local primaryPart = target.PrimaryPart
		or target:FindFirstChild("UpperTorso")
		or target:FindFirstChildWhichIsA("BasePart")

	if not primaryPart then
		warn("Target model has no valid BasePart to track!")
		return nil
	end

	local targetPos = primaryPart.Position
	local muzzlePos = self.MuzzleFlash.Position
	local distance = (targetPos - muzzlePos).Magnitude
	local timeToTarget = distance / self.WeaponData.Velocity

	local predictedPos = targetPos + (primaryPart.Velocity * timeToTarget)

	return predictedPos
end
function Turret:Update(dt: number)
	self.LastScanned += dt
	self.LastUpdatedOverlap += dt
	self.LastShot += dt

	if not self.Active then
		return
	end

	-- 1. UPDATE TARGET OVERLAP LIST
	if self.LastUpdatedOverlap >= OVERLAP_LIST_UPDATE_INTERVAL then
		self:UpdateOverlapParams()
		self.LastUpdatedOverlap = 0
	end

	-- 2. SCAN FOR ENEMIES & SHOOT
	if self.LastScanned >= self.ScanInterval then
		-- We scan and cache the target on the turret object itself (self.CurrentTarget)
		self.CurrentTarget = self:ScanForEnemies()
		if self.CurrentTarget then
			self:FireTurret()
			self.LastScanned = 0
		end
	end

	-- 3. SMOOTH ROTATION
	-- We check if our cached target is still valid and point turret towards the target
	if self.CurrentTarget and self.CurrentTarget.Parent then
		local pos = self:PredictTargetPosition()

		local randomOffset = Vector3.new(
			RandomModule.GetRandomIntBetween(-100, 100) / 100 * self.MaxSpreadDeg,
			RandomModule.GetRandomIntBetween(-100, 100) / 100 * self.MaxSpreadDeg,
			RandomModule.GetRandomIntBetween(-100, 100) / 100 * self.MaxSpreadDeg
		)
		self:PointTurretTowards(pos + randomOffset, dt)
	else
		-- Reset target if they died or despawned
		self.CurrentTarget = nil
	end
end
function Turret:PointTurretTowards(position: Vector3, dt: number)
	local currentPivot = self.Model:GetPivot()

	-- 1. Create a CFrame that stays at the current position but faces the target
	local targetCFrame = CFrame.lookAt(currentPivot.Position, position)

	-- 2. Calculate the interpolation step
	local alpha = math.clamp(self.TurnSpeed * dt, 0, 1)

	-- 3. Interpolate the actual CFrames (smoothly blending the rotation)
	local newPivot = currentPivot:Lerp(targetCFrame, alpha)

	-- 4. Apply the updated CFrame back to the model
	self.Model:PivotTo(newPivot)
end

function Turret:ScanForEnemies()
	local partsInRadius = workspace:GetPartsInPart(self.RadiusPart, self.OverlapParams)

	for _, part in partsInRadius do
		if not part:IsA("BasePart") then
			return
		end

		local hasParent = part.Parent
		if not hasParent then
			continue
		end

		for _, tag in self.TargetTags do
			if not CollectionService:HasTag(hasParent, tag) then
				continue
			end

			if CollectionService:HasTag(hasParent, "Dead") then
				continue
			end

			-- Check if field of view
			local dir = (hasParent:GetPivot().Position - self.ShootPoint.WorldPosition).Unit * 1000
			local canSee = workspace:Raycast(self.ShootPoint.WorldPosition, dir)

			if not canSee or not canSee.Instance:IsDescendantOf(hasParent) then
				continue
			end

			-- Means target found, should return character model of target
			self.CurrentTarget = hasParent
			self.State = "Attacking"
			return hasParent
		end
	end

	-- NOTHING FOUND IN RADIUS
	self.CurrentTarget = nil
	self.State = "Idle"
	return
end

function Turret:StopLoop()
	self.Janitor:Remove("TurretLoop")
	self.CurrentTarget = nil
	self.State = "Idle"
end
function Turret:RemoveEnemyTag(tag: string)
	for idx, currentTag in self.TargetTags do
		if currentTag == tag then
			table.remove(self.TargetTags, idx)
			return
		end
	end
end

function Turret:Destroy()
	self:StopLoop()
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

function Turret:ActivateMuzzleFlash()
	if not self.MuzzleFlash then
		warn("Muzzle flash reference missing, can't activate")
		return
	end

	ServerEffectsDisplayer:DisplayMuzzleFlash(self.Model, self.Type)
end

function Turret:FireTurret(dt: number)
	if self.LastShot < self.ShotDelay then
		return
	end
	self.LastShot = 0

	if self.GunType == "Shotgun" then
		self:SpreadShot()
		self:ActivateMuzzleFlash()
	else
		self:SingleShot()
		self:ActivateMuzzleFlash()
	end
end
function Turret:SingleShot()
	local projectileData = self.ProjectileData
	local context = nil
	if not projectileData then
		warn("Projectile data invalid, can't shoot")
		return
	end

	if not ProjectileContext.Solver then
		warn("ProjectileContext Solver reference missing in Turret class")
		return
	end

	context = ProjectileContext.BulletContext.new({
		Origin = self.ShootPoint.WorldPosition,
		Direction = self.ShootPoint.WorldAxis,
		Speed = self.WeaponData.Velocity,
		RaycastParams = self.ShootRaycastParams,
	})

	context.UserData.Owner = self.Model
	context.UserData.Damage = self.WeaponData.Damage
	context.UserData.ProjectileType = "Bullet"
	context.UserData.GunType = self.GunType

	if not context then
		warn("Singleshot context is invalid")
		return
	end

	ProjectileContext.Solver:Fire(context, projectileData)
end

function Turret:SpreadShot()
	local pelletCount = self.WeaponData.PelletsPerShot
	local maxSpreadAngle = self.WeaponData.MaxSpreadAngle
	local projectileData = self.WeaponData.ProjectileData

	if not projectileData then
		warn("Vetra projectile data is missing!")
		return
	end
	if not pelletCount then
		warn(`Pellet count not specified for {self.Type}`)
		return
	end

	for _ = 1, pelletCount do
		local spreadDir = Utility.GetShotgunSpreadDirection(self.ShootPoint.WorldAxis, maxSpreadAngle)
		local context = ProjectileContext.BulletContext.new({
			Origin = self.ShootPoint.WorldPosition,
			Direction = spreadDir,
			Speed = self.WeaponData.Velocity,
			RaycastParams = self.ShootRaycastParams,
		})

		context.UserData.Owner = self.Model
		context.UserData.Damage = self.WeaponData.Damage
		context.UserData.ProjectileType = "Bullet"
		context.UserData.GunType = self.GunType

		ProjectileContext.Solver:Fire(context, projectileData)
	end
end

return Turret
