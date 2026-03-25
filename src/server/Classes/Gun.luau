local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ClassTypes = require(script.Parent.ClassTypes)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)

type Human = ClassTypes.Human
type Gun = ClassTypes.Gun
type Destroyable = ClassTypes.Destroyable
local Gun = {}
Gun.__index = Gun

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

function Gun.new(gunName: string, humanClass: Human, player: Player | Model): Gun
	if not GunData[gunName] then
		error("Gun doesn't exist")
	end

	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()
	self.Tool = nil
	self.GunName = gunName
	self.MaxAmmo = GunData[gunName].MaxAmmo
	self.CurrentAmmo = GunData[gunName].MaxAmmo
	self.ShootPoint = nil
	self.Handle = nil
	self.ShotDelay = GunData[gunName].ShotDelay
	self.LastShot = 0
	self.Damage = GunData[gunName].Damage
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
	self.FastCast = FastCast.new()
	self.BulletVelocity = GunData[gunName].Velocity
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	self.ProjectileData.AutoIgnoreContainer = true

	self:ConnectProjectileEvents()

	return self
end

function Gun:AddCollisionConstraints()
	local bodyParts = self.HumanClassRef.BodyParts
	for i = 1, 3 do
		local collisionConstraint = Instance.new("NoCollisionConstraint")
		collisionConstraint.Part0 = bodyParts["UpperRightArm"]
	end
end
function Gun:HitPlayer(raycastResult: RaycastResult)
	local hitHumanoid = GetHumanoidFromHit(raycastResult.Instance)
	local isAccessory = raycastResult.Instance:FindFirstAncestorOfClass("Accessory")

	if not hitHumanoid then
		return false
	end

	if isAccessory then
		return false
	end

	-- hit body part
	GunSignals.PlayerHit:Fire(raycastResult, hitHumanoid, self.Damage)
	print(`{raycastResult.Instance.Name} hit!`)
	return true
end

function Gun:HitDestroyable(raycastResult: RaycastResult)
	local instance = raycastResult.Instance
	local destroyableClass: Destroyable = DestroyableManager.Destroyables[instance]
	if not destroyableClass then
		return
	end

	destroyableClass:Damage(self.Damage)

	return true
end

-- This should be executed last, as every other option should be exhausted before deciding we've hit
-- the environment.
function Gun:HitEnvironment(raycastResult: RaycastResult)
	-- hit environment
	local hitPos = CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
	GunSignals.DisplayBulletHole:Fire(hitPos)
end

function Gun:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _)
		local hitPlayer = self:HitPlayer(raycastResult)
		if hitPlayer then
			return
		end

		local hitDestroyable = self:HitDestroyable(raycastResult)
		if hitDestroyable then
			return
		end

		Gun:HitEnvironment(raycastResult)
	end))
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

	if adsDir and adsPosition then
		self.FastCast:Fire(adsPosition, adsDir, self.BulletVelocity, self.ProjectileData)
	else
		self.FastCast:Fire(
			self.ShootPoint.WorldPosition,
			self.ShootPoint.WorldCFrame.LookVector,
			self.BulletVelocity,
			self.ProjectileData
		)
	end

	self.CurrentAmmo -= 1

	self.CurrentAmmo = math.clamp(self.CurrentAmmo, 0, self.MaxAmmo)
	self.LastShot = os.clock()

	self:ActivateMuzzleFlash()

	if self.Reloading then
		self.Reloading = false
	end

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
	setmetatable(self, nil)
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
	self.Reloading = false

	return self.CurrentAmmo
end

function Gun:AddGunToInventory()
	local clone: Tool = ServerStorage.Templates:FindFirstChild(self.GunName):Clone()
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
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { excludeModel, self.Tool }

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
		-- remove this later, NPC auto equips gun for now
		self.HumanClassRef:EquipGun(clone)
	end
end
return Gun
