local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ClassTypes = require(script.Parent.ClassTypes)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)

type Human = ClassTypes.Human
type Gun = ClassTypes.Gun
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

function Gun:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _)
		print(raycastResult.Material)

		--check if hit player
		local hitHumanoid = GetHumanoidFromHit(raycastResult.Instance)
		local isAccessory = raycastResult.Instance:FindFirstAncestorOfClass("Accessory")

		-- hit environment
		if not hitHumanoid then
			local hitPos = CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
			GunSignals.DisplayBulletHole:Fire(hitPos)
			return
		end

		if isAccessory then
			return
		end

		-- hit body part
		GunSignals.PlayerHit:Fire(raycastResult, hitHumanoid, self.Damage)
		print(`{raycastResult.Instance.Name} hit!`)
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

function Gun:AddGunToInventory()
	local clone: Tool = ServerStorage.Templates:FindFirstChild(self.GunName):Clone()
	self.Tool = clone
	self.ShootPoint = clone:FindFirstChild("ShootPoint")

	local muzzle = clone:FindFirstChild("MuzzleFlash")
	if not muzzle then
		error("Missing muzzle flash reference")
	end

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
