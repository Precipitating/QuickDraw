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

local function GetCharacterFromHit(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

function Gun.new(humanClass: Human, player: Player): Gun
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()
	self.Tool = nil
	self.MaxAmmo = 6
	self.CurrentAmmo = 6
	self.ShootPoint = nil
	self.ShotDelay = 0.1
	self.CanShoot = true
	self.Damage = 20
	self.CurrentCooldown = -1
	self.PlayerRef = player
	self.HumanClassRef = humanClass
	self.MuzzleFlash = nil

	-- projectile data
	self.FastCast = FastCast.new()
	self.BulletVelocity = 350
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { player.Character }
	self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	self.ProjectileData.AutoIgnoreContainer = true

	self:AddGunToInventory(player)
	self:ConnectProjectileEvents()
	return self
end

function Gun:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(activeCast, raycastResult: RaycastResult, segmentVelocity)
		print("SOMEONE GOT HIT")
		print(raycastResult.Material)

		--check if hit player
		local hitPlayer = GetCharacterFromHit(raycastResult.Instance)

		if hitPlayer then
			print("player hit")
		else
			workspace.BulletHole:PivotTo(
				CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
			)
		end
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

	self.FastCast:Fire(self.ShootPoint.WorldPosition, self.ShootPoint.WorldCFrame.LookVector, 350, self.ProjectileData)

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

	GunSignals.FireMuzzleFlash:Fire(self.PlayerRef, self.Tool)
end

function Gun:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
end

function Gun:AddGunToInventory(player: Player)
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

	clone.Parent = self.PlayerRef.Backpack
	GunSignals.ConnectGunSignal:Fire(player, clone)
	self.Janitor:Add(self.Tool)
end
return Gun
