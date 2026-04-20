local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunSignals = require(script.Parent.GunSignals)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)

type Human = ClassTypes.Human
type Gun = ClassTypes.Gun

local Gun = {}
Gun.__index = Gun

function Gun.new(gunName: string, humanClass: Human, player: Player | Model): Gun
	if not GunData[gunName] then
		error("Gun doesn't exist")
	end
	local gunData = GunData[gunName]
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()

	self.Tool = nil
	self.GunName = gunName
	self.MaxAmmo = gunData.MaxAmmo
	self.CurrentAmmo = gunData.MaxAmmo
	self.Reloading = false
	self.GunType = gunData.GunType
	self.ShootPoint = nil
	self.Handle = nil
	self.Speed = gunData.Velocity
	self.ShotDelay = gunData.ShotDelay
	self.LastShot = 0
	self.Damage = gunData.Damage
	self.CurrentCooldown = -1

	-- if its NPC, its their model, else player instance
	self.PlayerRef = player
	if player:IsA("Player") then
		self.PlayerRef = player
	end
	self.HumanClassRef = humanClass
	self.MuzzleFlash = nil
	self.Equipped = false

	-- projectile data
	-- self.FastCast = FastCast.new()
	-- self.BulletVelocity = gunData.Velocity
	-- self.ProjectileData = FastCast.newBehavior()
	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	-- self.ProjectileData.AutoIgnoreContainer = true

	self:ConnectProjectileEvents()

	return self
end

function Gun:ConnectProjectileEvents()
	-- self.Janitor:Add(VetraSignals.OnHit:Connect(function(context, result, velocity)
	-- 	local hitPlayer = self:HitPlayer(result)
	-- 	if hitPlayer then
	-- 		return
	-- 	end

	-- 	local hitDestroyable = self:HitDestroyable(result)
	-- 	if hitDestroyable then
	-- 		return
	-- 	end

	-- 	Gun:HitEnvironment(result)
	-- end))

	-- Fastcast
	-- self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _)
	-- 	local hitPlayer = self:HitPlayer(raycastResult)
	-- 	if hitPlayer then
	-- 		return
	-- 	end

	-- 	local hitDestroyable = self:HitDestroyable(raycastResult)
	-- 	if hitDestroyable then
	-- 		return
	-- 	end

	-- 	Gun:HitEnvironment(raycastResult)
	-- end))
end

function Gun:SingleShot(adsDir: Vector3?, adsPosition: Vector3?)
	local projectileData = GunData[self.GunName].ProjectileData
	local context = nil
	if not projectileData then
		warn("Projectile data invalid, can't shoot")
		return
	end

	if not ProjectileContext.Solver then
		warn("ProjectileContext Solver reference missing in Gun class")
		return
	end

	if adsDir and adsPosition then
		context = ProjectileContext.BulletContext.new({
			Origin = adsPosition,
			Direction = adsDir,
			Speed = self.Speed,
			RaycastParams = self.RaycastParams,
		})
	else
		context = ProjectileContext.BulletContext.new({
			Origin = self.ShootPoint.WorldPosition,
			Direction = self.ShootPoint.WorldCFrame.LookVector,
			Speed = self.Speed,
			RaycastParams = self.RaycastParams,
		})
	end

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

-- For shotgun
function Gun:GetSpreadDirection(baseDirection: Vector3, maxDegrees: number)
	-- Use a circular spread pattern
	-- Pick a random angle and random radius within the cone
	local angle = RandomModule.GetRandom() * 2 * math.pi
	local radius = math.sqrt(RandomModule.GetRandom()) * math.rad(maxDegrees)

	local randomX = math.cos(angle) * radius
	local randomY = math.sin(angle) * radius

	local spreadCFrame = CFrame.new(Vector3.zero, baseDirection) * CFrame.Angles(randomX, randomY, 0)

	return spreadCFrame.LookVector
end

function Gun:SpreadShot(adsDir: Vector3?, adsPosition: Vector3?)
	local pelletCount = GunData[self.GunName].PelletsPerShot
	local maxSpreadAngle = GunData[self.GunName].MaxSpreadAngle
	local projectileData = GunData[self.GunName].ProjectileData

	if not projectileData then
		warn("Vetra projectile data is missing!")
		return
	end
	if not pelletCount then
		warn(`Pellet count not specified for {self.GunName}`)
		return
	end

	-- If ADS...
	if adsDir and adsPosition then
		for _ = 1, pelletCount do
			local spreadDir = self:GetSpreadDirection(adsDir, maxSpreadAngle)
			local context = ProjectileContext.BulletContext.new({
				Origin = adsPosition,
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
	else
		for _ = 1, pelletCount do
			local spreadDir = self:GetSpreadDirection(self.ShootPoint.WorldCFrame.LookVector, maxSpreadAngle)
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
end

-- if adsPosition and adsDir is specified, we shoot from middle of screen
function Gun:ShootGun(adsPosition: Vector3?, adsDir: Vector3?)
	local now = os.clock()
	if now - self.LastShot < self.ShotDelay then
		return false
	end

	if self.CurrentAmmo <= 0 or self.CurrentCooldown > 0 then
		return false
	end

	if self.Reloading then
		self:StopReloading()
	end

	if self.GunType == "Shotgun" then
		self:SpreadShot(adsDir, adsPosition)
	else
		self:SingleShot(adsDir, adsPosition)
	end

	self.CurrentAmmo -= 1

	self.CurrentAmmo = math.clamp(self.CurrentAmmo, 0, self.MaxAmmo)
	self.LastShot = os.clock()

	self:ActivateMuzzleFlash()

	return true
end

function Gun:ActivateMuzzleFlash()
	if not self.MuzzleFlash then
		warn("Muzzle flash reference missing, can't activate")
		return
	end

	-- if playerRef is nil, it'll be an NPC
	GunSignals.FireMuzzleFlash:Fire(self.PlayerRef, self.Tool)
end

function Gun:Destroy()
	self.Janitor:Destroy()
	self.Tool:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

function Gun:Reload()
	local reloadTimePerBullet = GunData[self.GunName].ReloadTimePerBullet
	local reloadSound = GunData[self.GunName].ReloadSoundName
	local bulletsToReload = self.MaxAmmo - self.CurrentAmmo

	if not self.Reloading then
		self.Reloading = true
	end

	for _ = 1, bulletsToReload do
		task.wait(reloadTimePerBullet)

		if not self.Equipped or not self.Reloading or self.HumanClassRef.Dead then
			return self.CurrentAmmo
		end

		self.CurrentAmmo = math.min(self.MaxAmmo, self.CurrentAmmo + 1)

		if self.Handle then
			ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSound, self.Handle.CFrame)
		end
	end

	-- Finished loading to max ammo without interruptions, update flags.
	self:StopReloading()

	return self.CurrentAmmo
end

function Gun:StopReloading()
	self.Reloading = false

	if self.PlayerRef and self.PlayerRef:IsA("Player") then
		GunSignals.StoppedReloading:Fire(self.PlayerRef)
	end
end

function Gun:DisableCollision(tool: Tool)
	for _, object in tool:GetChildren() do
		if object:IsA("BasePart") then
			object.CanCollide = false
		end
	end
end
function Gun:AddGunToInventory()
	local clone: Tool = ReplicatedStorage.Shared.Templates:FindFirstChild(self.GunName):Clone()
	self.Tool = clone
	self.ShootPoint = clone:WaitForChild("ShootPoint", 10)
	self.Handle = clone:WaitForChild("Handle", 10)

	local muzzle = clone:FindFirstChild("MuzzleFlash", true)
	if not muzzle then
		error("Missing muzzle flash reference")
	end

	self.Janitor:Add(clone.Equipped:Connect(function(_)
		self.Equipped = true
	end))
	self.Janitor:Add(clone.Unequipped:Connect(function(_)
		self.Equipped = false
	end))
	-- if its NPC, playerRef should be a model instead of a player instance.
	local excludeModel = self.PlayerRef:IsA("Player") and self.PlayerRef.Character or self.PlayerRef
	self.RaycastParams.FilterDescendantsInstances = { excludeModel, self.Tool }

	self.MuzzleFlash = muzzle:FindFirstChildOfClass("Attachment")
	if not self.MuzzleFlash then
		error("Missing muzzle flash attachment reference")
	end

	if self.PlayerRef:IsA("Player") then
		clone.Parent = self.PlayerRef.Backpack
		GunSignals.ConnectGunSignal:Fire(self.PlayerRef, clone)
		self.Janitor:Add(self.Tool)
	else
		-- should be HumanNPC class
		-- NPC auto equips gun for now
		self:DisableCollision(clone)
		self.HumanClassRef:EquipGun(clone)
	end
end
return Gun
