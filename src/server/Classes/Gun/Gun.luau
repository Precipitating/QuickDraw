local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunSignals = require(script.Parent.GunSignals)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local ProjectileContext = require(script.Parent.Parent.Parent.ProjectilesHandler.ProjectileContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local NpcState = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local GunRaycastParam = RaycastParams.new()
GunRaycastParam.CollisionGroup = "Projectile"

type Human = ClassTypes.Human
type Gun = ClassTypes.Gun

local Gun = {}
Gun.__index = Gun

function Gun.new(
	gunName: string,
	humanClass: Human | LightweightNpcTypes.npcRecordType,
	player: Player? | Model?,
	tool: Tool?
): Gun
	if not GunData[gunName] then
		error("Gun doesn't exist")
	end
	local gunData = GunData[gunName]
	local self = setmetatable({}, Gun)
	self.Janitor = Janitor.new()

	self.GunData = gunData
	self.Tool = tool
	self.Name = gunName
	self.ReloadTime = gunData.ReloadTime or gunData.ReloadTimePerBullet
	self.MaxAmmo = gunData.MaxAmmo
	self.ReloadSound = gunData.ReloadSoundName
	self.ReloadSoundStart = gunData.ReloadSoundStartName
	self.MaxAmmoStack = gunData.MaxAmmoStack
	self.EquipWalkspeedMultiplier = gunData.EquipWalkspeedMultiplier or 1
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

	-- if its NPC, its their model, else player instance
	self.PlayerRef = player
	if player and player:IsA("Player") then
		self.PlayerRef = player
	end
	self.HumanClassRef = humanClass

	--
	local muzzleFlash = tool and tool:FindFirstChild("MuzzleFlash", true)
	self.MuzzleFlash = if muzzleFlash then muzzleFlash:FindFirstChildOfClass("Attachment") else nil

	self:InitializeEvents()

	return self
end

function Gun:InitializeEvents()
	if not self.Tool then
		return
	end
	local tool: Tool = self.Tool

	self.Janitor:Add(tool.Equipped:Connect(function()
		self.HoldingGun = true
	end))

	self.Janitor:Add(tool.Unequipped:Connect(function()
		self.HoldingGun = false
	end))
end

function Gun:InitializeAmmoValues()
	self.Tool:SetAttribute("CurrentAmmo", self.CurrentAmmo)
	self.Tool:SetAttribute("AmmoReserve", self.AmmoReserve)
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
		RaycastParams = GunRaycastParam,
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
			RaycastParams = GunRaycastParam,
		})

		context.UserData.Owner = self.PlayerRef
		context.UserData.Damage = self.Damage
		context.UserData.ProjectileType = "Bullet"
		context.UserData.GunType = self.GunType

		ProjectileContext.Solver:Fire(context, projectileData)
	end
end

function Gun:UpdateAmmo(amount: number)
	if not self.Tool then
		return false
	end
	self.CurrentAmmo = math.clamp(self.CurrentAmmo + amount, 0, self.MaxAmmo)

	self.Tool:SetAttribute("CurrentAmmo", self.CurrentAmmo)

	return true
end

function Gun:UpdateAmmoReserve(amount: number)
	if not self.Tool then
		return
	end

	self.AmmoReserve = math.clamp(self.AmmoReserve + amount, 0, self.MaxAmmo * self.MaxAmmoStack)

	self.Tool:SetAttribute("AmmoReserve", self.AmmoReserve)
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

function Gun:BulletByBulletReload(bulletsToReload: number)
	local isPlayer = self.PlayerRef and self.PlayerRef:IsA("Player")

	if isPlayer then
		PopupGUI:NewPopup(self.PlayerRef, 2, `Start reloading, {self.ReloadTime} seconds per round`)
	end
	for _ = 1, bulletsToReload do
		task.wait(self.ReloadTime)

		if self.HumanClassRef and (self.HumanClassRef.Dead or self.HumanClassRef.npcState == NpcState.Dying) then
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
			ServerSoundHandler:Play3DOneShotToOthers(nil, self.ReloadSound, self.Handle.CFrame.Position)
		end
	end

	return nil
end

function Gun:ReloadAsMagazine(bulletsToReload: number)
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

		PopupGUI:NewPopup(self.PlayerRef, 2, `Start reloading magazine, {self.ReloadTime} seconds`)
	end

	ServerSoundHandler:Play3DOneShotToOthers(nil, self.ReloadSound, self.Handle.CFrame.Position)

	task.wait(self.ReloadTime)

	if not self.Reloading then
		return
	end
	if Utility.IsHoldingTool(character, self.Name) then
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

	local gunType = self.GunType
	local reloadSoundStart = self.ReloadSoundStartName
	local bulletsToReload = self.MaxAmmo - self.CurrentAmmo

	--
	if bulletsToReload <= 0 then
		return
	end

	if self.Reloading then
		return
	end
	self.Reloading = true

	if reloadSoundStart then
		ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSoundStart, self.Handle.CFrame.Position)
	end

	if not gunType then
		error("Current gun has no gun type!")
		return
	end

	if gunType == "Automatic" then
		self:ReloadAsMagazine(bulletsToReload)
	else
		self:BulletByBulletReload(bulletsToReload)
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
