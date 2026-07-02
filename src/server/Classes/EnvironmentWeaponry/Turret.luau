local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local Turret = {}
Turret.__index = Turret

function Turret.new(modelRef: Model?, range: number?)
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
	--
	self.GunType = self.WeaponData.GunType
	self.ShotDelay = self.WeaponData.ShotDelay
	self.ProjectileData = self.WeaponData.ProjectileData
	self.Range = range or 100
	self.ScanInterval = 0.2
	self.State = "Idle"
	self.Active = true
	self.LastShot = 0
	self.TargetTags = { "Player", "NPC" }
	self.CurrentTarget = nil
	self.ShootPoint = modelRef:FindFirstChild("ShootPoint")
	self.MuzzleFlash = modelRef:FindFirstChild("MuzzleFlash")
	self.MuzzleFlashEffects = self.MuzzleFlash and self.MuzzleFlash:FindFirstChildOfClass("Attachment")
	self.RotationSpeed = 1

	return self
end

function Turret:AddEnemyTag(tag: string)
	table.insert(self.TargetTags, tag)
end

function Turret:Update(dt: number)
	self.LastShot += dt
	if not self.Active then
		return
	end
	if self.LastShot <= self.ScanInterval then
		return
	end

	local foundEnemy = self:ScanForEnemies()

	if not foundEnemy then
		return
	end
	self:PointTurretTowards(foundEnemy:GetPivot().Position, dt)
	self:FireTurret()
end

function Turret:PointTurretTowards(position: Vector3, dt)
	local pivot = self.Model:GetPivot().Position

	local targetCFrame = CFrame.lookAt(pivot, position)
	local alpha = math.clamp(self.Config.TurnSpeed * dt, 0, 1)
	local newPivot = pivot:Lerp(targetCFrame, alpha)
	self.Model:PivotTo(newPivot)
end

function Turret:ScanForEnemies()
	local pivotCFrame = self.Model:GetPivot()
	local partsInRadius = workspace:GetPartBoundsInRadius(pivotCFrame.Position, self.Range)

	for _, part in partsInRadius do
		local hasParent = part.Parent
		if not hasParent then
			continue
		end

		for _, tag in self.TargetTags do
			if not CollectionService:HasTag(hasParent, tag) then
				continue
			end

			-- Means target found, should return character model of target
			return hasParent
		end
	end

	-- NOTHING FOUND IN RADIUS
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
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

function Turret:ActivateMuzzleFlash()
	if not self.MuzzleFlash then
		warn("Muzzle flash reference missing, can't activate")
		return
	end

	ServerEffectsDisplayer:DisplayMuzzleFlash(self.Tool)
end

function Turret:FireTurret()
	local now = os.clock()
	if now - self.LastShot < self.ShotDelay then
		return
	end
	self.LastShot = now

	if self.GunType == "Shotgun" then
		self:SpreadShot()
	else
		self:SingleShot()
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
		Speed = self.Speed,
		RaycastParams = self.RaycastParams,
	})

	context.UserData.Owner = self.PlayerRef
	context.UserData.Damage = self.Damage
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
			Speed = self.Speed,
			RaycastParams = self.RaycastParams,
		})

		context.UserData.Owner = self.PlayerRef
		context.UserData.Damage = self.Damage
		context.UserData.ProjectileType = "Bullet"
		context.UserData.GunType = self.GunType

		ProjectileContext.Solver:Fire(context, projectileData)
	end
end

return Turret
