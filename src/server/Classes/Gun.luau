local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ClassTypes = require(script.Parent.ClassTypes)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)

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

function Gun.new(humanClass: Human, player: Player | Model): Gun
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()
	self.Tool = nil
	self.MaxAmmo = 999
	self.CurrentAmmo = 999
	self.ShootPoint = nil
	self.ShotDelay = 0.15
	self.CanShoot = true
	self.Damage = 30
	self.CurrentCooldown = -1

	-- if its NPC, its their model, else player instance
	self.PlayerRef = player
	if player:IsA("Player") then
		self.PlayerRef = player
	end
	self.HumanClassRef = humanClass
	self.MuzzleFlash = nil

	-- if its NPC, player should be a model instead of a player instance.
	local excludeModel = self.PlayerRef:IsA("Player") and self.PlayerRef.Character or player
	-- projectile data
	self.FastCast = FastCast.new()
	self.BulletVelocity = 900
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { excludeModel }
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
		local playerHumanoid: Humanoid? = GetHumanoidFromHit(hitHumanoid)
		if not playerHumanoid then
			warn(`[ConnectProjectileEvents] Cannot get humanoid from character!`)
			return
		end

		GunSignals.PlayerHit:Fire(raycastResult, playerHumanoid, self.Damage)
		print(`{raycastResult.Instance.Name} hit!`)
	end))
end

function Gun:ShootGun()
	if not self.CanShoot then
		warn("Can't shoot, cooldown")
		return false
	end

	if self.CurrentAmmo <= 0 or self.CurrentCooldown > 0 then
		return false
	end

	self.CanShoot = false

	self.FastCast:Fire(
		self.ShootPoint.WorldPosition,
		self.ShootPoint.WorldCFrame.LookVector,
		self.BulletVelocity,
		self.ProjectileData
	)

	self.CurrentAmmo -= 1

	self.CurrentAmmo = math.clamp(self.CurrentAmmo, 0, self.MaxAmmo)
	task.delay(self.ShotDelay, function()
		self.CanShoot = true
	end)

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
	local clone: Tool = ServerStorage.Templates.Revolver:Clone()
	self.Tool = clone
	self.ShootPoint = clone:FindFirstChild("ShootPoint")

	local muzzle = clone:FindFirstChild("MuzzleFlash")
	if not muzzle then
		error("Missing muzzle flash reference")
	end

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
		self.HumanClassRef:EquipGun(clone)
	end
end
return Gun
