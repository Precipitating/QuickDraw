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
	self.MaxSpreadStuds = 3
	self.LastScanned = 0
	self.TargetTags = { "Player" }
	self.IKControl = modelRef:FindFirstChild("IKControl", true)
	self.ShootPoint = modelRef:FindFirstChild("ShootPoint", true)
	self.MuzzleFlash = modelRef:FindFirstChild("MuzzleFlash")
	self.MuzzleFlashEffects = self.MuzzleFlash and self.MuzzleFlash:FindFirstChildOfClass("Attachment")
	self.TurnSpeed = 5
	self.OverlapParams = OverlapParams.new()
	self.ShootRaycastParams = RaycastParams.new()
	self.ShootRaycastParams.FilterDescendantsInstances = { modelRef }
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

function Turret:GetRandomSpreadVector()
	local randomX = RandomModule.GetRandomDecimalBetween(-1, 1) * self.MaxSpreadStuds
	local randomY = RandomModule.GetRandomDecimalBetween(-1, 1) * self.MaxSpreadStuds

	return Vector3.new(randomX, randomY, 0)
end

function Turret:GetTargetOffset()
	if not self.IKControl.Target then
		return
	end
	local target = self.IKControl.Target

	local targetPos = target.Position
	local muzzlePos = self.MuzzleFlash.Position
	local distance = (targetPos - muzzlePos).Magnitude
	local timeToTarget = distance / self.WeaponData.Velocity

	local predictedOffset = (target.Velocity * timeToTarget)

	return predictedOffset
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
		self:ScanForEnemies()
		if self.IKControl.Target then
			self:FireTurret()
			self.LastScanned = 0
		end
	end
end

function Turret:isValidTarget(model)
	if not model or not model.Parent then
		return false
	end
	if CollectionService:HasTag(model, "Dead") then
		return false
	end

	local targetPosition = model:GetPivot().Position

	-- cheap box check: convert to RadiusPart's local space and compare against half-size
	local localPos = self.RadiusPart.CFrame:PointToObjectSpace(targetPosition)
	local halfSize = self.RadiusPart.Size * 0.5
	if math.abs(localPos.X) > halfSize.X or math.abs(localPos.Y) > halfSize.Y or math.abs(localPos.Z) > halfSize.Z then
		return false
	end

	local origin = self.ShootPoint.WorldPosition
	local dir = (targetPosition - origin).Unit * 1000
	local canSee = workspace:Raycast(origin, dir)
	if not canSee or not canSee.Instance:IsDescendantOf(model) then
		return false
	end

	return true
end

function Turret:ScanForEnemies()
	local origin = self.ShootPoint.WorldPosition

	-- 1. Stick with the current target if it's still good -- skip the scan entirely
	if self.CurrentTargetModel and self:isValidTarget(self.CurrentTargetModel) then
		self.IKControl.Target = self.CurrentTargetModel:FindFirstChild("UpperTorso")
			or self.CurrentTargetModel:FindFirstChildWhichIsA("BasePart")
		self.State = "Attacking"
		return
	end

	-- 2. Current target lost -- fall back to the full scan for a new one
	self.CurrentTargetModel = nil
	local partsInRadius = workspace:GetPartsInPart(self.RadiusPart, self.OverlapParams)
	local bestTargetPart = nil

	for _, part in partsInRadius do
		if not part:IsA("BasePart") then
			continue
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

			local targetPosition = hasParent:GetPivot().Position
			local dir = (targetPosition - origin).Unit * 1000
			local canSee = workspace:Raycast(origin, dir)
			if not canSee or not canSee.Instance:IsDescendantOf(hasParent) then
				continue
			end

			bestTargetPart = hasParent:FindFirstChild("UpperTorso")
				or hasParent:FindFirstChildWhichIsA("BasePart")
				or part
			self.CurrentTargetModel = hasParent
			break
		end
		if bestTargetPart then
			break
		end
	end

	if bestTargetPart then
		self.IKControl.Target = bestTargetPart
		self.State = "Attacking"
	else
		self.IKControl.Target = nil
		self.State = "Idle"
	end
end

function Turret:StopLoop()
	self.Janitor:Remove("TurretLoop")
	self.IKControl.Target = nil
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

	local getOffset = self:GetTargetOffset()
	local spreadVector = self:GetRandomSpreadVector()

	self.IKControl.Offset = CFrame.new(getOffset + spreadVector)

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
