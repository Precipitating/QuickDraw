local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
export type Gun = {
	Tool: Tool?,
	MaxAmmo: number,
	CurrentAmmo: number,
	ShotDelay: number,
	ShootPoint: Attachment?,
	PlayerRef: Player?,
	CanShoot: boolean,
	CurrentCooldown: number,
	AddGunToInventory: (self: Gun) -> (),
	ShootGun: (self: Gun) -> (),
	MuzzleFlash: Attachment?,
}

local Gun = {}
Gun.__index = Gun

function Gun.new(player: Player): Gun
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()
	self.Tool = nil
	self.MaxAmmo = 6
	self.CurrentAmmo = 6
	self.ShootPoint = nil
	self.ShotDelay = 1
	self.CanShoot = true
	self.CurrentCooldown = -1
	self.PlayerRef = player
	self.MuzzleFlash = nil

	self:AddGunToInventory(player)

	return self
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

	self.CurrentAmmo -= 1

	task.delay(self.ShotDelay, function()
		self.CanShoot = true
	end)

	self:ApplyPistolRecoil()
	self:ActivateMuzzleFlash()

	return true
end

function Gun:ActivateMuzzleFlash()
	if not self.MuzzleFlash then
		warn("Muzzle flash reference missing, can't activate")
		return
	end

	GunSignals.FireMuzzleFlash:Fire(self.PlayerRef, self.MuzzleFlash)
end

function Gun:ApplyPistolRecoil() end

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
