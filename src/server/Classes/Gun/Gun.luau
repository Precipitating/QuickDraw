local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunSignals = require(script.Parent.GunSignals)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

type Human = ClassTypes.Human
type Gun = ClassTypes.Gun

local Gun = {}
Gun.__index = Gun

function Gun.new(gunName: string, humanClass: Human, player: Player | Model, tool: Tool?): Gun
	if not GunData[gunName] then
		error("Gun doesn't exist")
	end
	local gunData = GunData[gunName]
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()

	self.Tool = tool or nil
	self.Name = gunName
	self.MaxAmmo = gunData.MaxAmmo
	self.MaxAmmoStack = gunData.MaxAmmoStack
	self.CurrentAmmo = gunData.MaxAmmo
	self.Jammed = false
	self.HoldingGun = false
	self.AmmoReserve = gunData.MaxAmmo * self.MaxAmmoStack
	self.Reloading = false
	self.GunType = gunData.GunType
	self.ShootPoint = if tool then tool:WaitForChild("ShootPoint") else nil
	self.Handle = if tool then tool:WaitForChild("Handle") else nil
	self.Speed = gunData.Velocity
	self.ShotDelay = gunData.ShotDelay
	self.LastShot = 0
	self.Damage = gunData.Damage
	self.CurrentAmmoIntValue = nil
	self.AmmoReserveIntValue = nil
	-- if its NPC, its their model, else player instance
	self.PlayerRef = player
	if player:IsA("Player") then
		self.PlayerRef = player
	end
	self.HumanClassRef = humanClass

	--
	local muzzleFlash = tool and tool:FindFirstChild("MuzzleFlash", true)
	self.MuzzleFlash = if muzzleFlash then muzzleFlash:FindFirstChildOfClass("Attachment") else nil

	-- projectile data
	-- self.FastCast = FastCast.new()
	-- self.BulletVelocity = gunData.Velocity
	-- self.ProjectileData = FastCast.newBehavior()
	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	-- self.ProjectileData.AutoIgnoreContainer = true

	return self
end

function Gun:InitializeAmmoValues()
	local currentAmmoVal: IntValue = Instance.new("IntValue")
	currentAmmoVal.Name = "CurrentAmmo"
	currentAmmoVal.Value = self.CurrentAmmo
	currentAmmoVal.Parent = self.Tool
	self.CurrentAmmoIntValue = currentAmmoVal

	local ammoReserveVal: IntValue = Instance.new("IntValue")
	ammoReserveVal.Name = "AmmoReserve"
	ammoReserveVal.Value = self.AmmoReserve
	ammoReserveVal.Parent = self.Tool
	self.AmmoReserveIntValue = ammoReserveVal
end

function Gun:SingleShot()
	local projectileData = GunData[self.Name].ProjectileData
	local context = nil
	if not projectileData then
		warn("Projectile data invalid, can't shoot")
		return
	end

	if not ProjectileContext.Solver then
		warn("ProjectileContext Solver reference missing in Gun class")
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

function Gun:SpreadShot()
	local gunName = self.Name
	local pelletCount = GunData[gunName].PelletsPerShot
	local maxSpreadAngle = GunData[gunName].MaxSpreadAngle
	local projectileData = GunData[gunName].ProjectileData

	if not projectileData then
		warn("Vetra projectile data is missing!")
		return
	end
	if not pelletCount then
		warn(`Pellet count not specified for {gunName}`)
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

function Gun:UpdateAmmo(amount: number)
	if amount > 0 and self.CurrentAmmo >= self.MaxAmmo then
		return false
	end
	self.CurrentAmmo = math.clamp(self.CurrentAmmo + amount, 0, self.MaxAmmo)

	if self.CurrentAmmoIntValue then
		self.CurrentAmmoIntValue.Value = self.CurrentAmmo
	end

	return true
end

function Gun:UpdateAmmoReserve(amount: number)
	self.AmmoReserve = math.clamp(self.AmmoReserve + amount, 0, self.MaxAmmo * self.MaxAmmoStack)
	if self.AmmoReserveIntValue then
		self.AmmoReserveIntValue.Value = self.AmmoReserve
	end
end

-- This is for NPCS, player shooting is handled on client via VetraNet
function Gun:ShootGun()
	local now = os.clock()
	if now - self.LastShot < self.ShotDelay then
		return false
	end

	if self.CurrentAmmo <= 0 then
		return false
	end

	if self.Reloading then
		self:StopReloading()
	end

	if self.GunType == "Shotgun" then
		self:SpreadShot()
	else
		self:SingleShot()
	end

	self:UpdateAmmo(-1)

	self.LastShot = os.clock()

	self:ActivateMuzzleFlash()

	return true
end

function Gun:ActivateMuzzleFlash()
	if not self.MuzzleFlash then
		warn("Muzzle flash reference missing, can't activate")
		return
	end

	-- NPC should only call this, as its from server to client
	ServerEffectsDisplayer:DisplayMuzzleFlash(self.Tool)
end

function Gun:Destroy()
	self.Janitor:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

function Gun:BulletByBulletReload(bulletsToReload: number, reloadTime: number, reloadSound: string)
	local isPlayer = self.PlayerRef and self.PlayerRef:IsA("Player")

	if isPlayer then
		PopupGUI:NewPopup(self.PlayerRef, 2, `Start reloading, {reloadTime} seconds per round`)
	end
	for _ = 1, bulletsToReload do
		task.wait(reloadTime)

		if self.HumanClassRef and self.HumanClassRef.Dead then
			return
		end
		if not self.Reloading then
			return
		end

		if isPlayer then
			if self.AmmoReserve <= 0 then
				return
			end
		end

		if not self.UpdateAmmo then
			return
		end

		self:UpdateAmmo(1)
		if isPlayer then
			self:UpdateAmmoReserve(-1)
		end

		if self.Handle then
			ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSound, self.Handle.CFrame)
		end
	end

	return nil
end

function Gun:ReloadAsMagazine(bulletsToReload: number, reloadTime: number, gunName: string, reloadSound: string)
	if not self.Handle then
		return
	end

	local character = self.HumanClassRef and self.HumanClassRef.Character

	if not character then
		warn("[Gun:ReloadAsMagazine] failed: Missing character ref")
		return
	end

	local dead = self.HumanClassRef.Dead
	if dead then
		return
	end

	if self.PlayerRef and self.PlayerRef:IsA("Player") then
		if self.AmmoReserve <= 0 then
			return
		end

		PopupGUI:NewPopup(self.PlayerRef, 2, `Start reloading magazine, {reloadTime} seconds`)
	end

	ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSound, self.Handle.CFrame)

	task.wait(reloadTime)

	if not self.Reloading then
		return
	end
	if Utility.IsHoldingTool(character, gunName) then
		self:UpdateAmmoReserve(-bulletsToReload)
		self:UpdateAmmo(bulletsToReload)
	else
		return
	end
end

function Gun:Reload()
	local gunName = self.Name
	local gunData = if gunName then GunData[gunName] else nil
	if not gunData then
		warn("[Gun:Reload] Missing gun data ")
		return
	end
	local reloadTime = gunData.ReloadTimePerBullet or gunData.ReloadTime
	local reloadSound = gunData.ReloadSoundName
	local gunType = gunData.GunType
	local reloadSoundStart = gunData.ReloadSoundStartName
	local bulletsToReload = self.MaxAmmo - self.CurrentAmmo
	if bulletsToReload <= 0 then
		return
	end

	if self.Reloading then
		return
	end
	self.Reloading = true

	if reloadSoundStart then
		ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSoundStart, self.Handle.CFrame)
	end

	if not gunType then
		error("Current gun has no gun type!")
		return
	end

	if gunType == "Automatic" then
		self:ReloadAsMagazine(bulletsToReload, reloadTime, gunName, reloadSound)
	else
		self:BulletByBulletReload(bulletsToReload, reloadTime, reloadSound)
	end

	-- Finished loading to max ammo without interruptions, update flags.
	if self.StopReloading then
		self:StopReloading()
	end
	return self.CurrentAmmo
end

function Gun:StopReloading(replicateToClient: boolean?)
	if not self.Reloading then
		return
	end

	self.Reloading = false

	if replicateToClient == nil or replicateToClient == true then
		if self.PlayerRef and self.PlayerRef:IsA("Player") then
			GunSignals.StoppedReloading:Fire(self.PlayerRef)
		end
	end
end

function Gun:ToggleCollision(state: boolean, tool: Tool?)
	local children = if tool then tool:GetChildren() else self.Tool:GetChildren()
	for _, object in children do
		if object:IsA("MeshPart") then
			object.CanCollide = state
		end
	end
end

return Gun
