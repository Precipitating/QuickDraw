local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ThrowableSignals = require(script.Parent.ThrowableSignals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)

local Throwable = {}

type Human = ClassTypes.Human
Throwable.__index = Throwable

local fragmentParam = RaycastParams.new()
fragmentParam.FilterType = Enum.RaycastFilterType.Exclude

function Throwable.new(throwableName: string, humanRef: Human?, ammo: number?, tool: Tool?)
	assert(ThrowableData[throwableName], "Throwable name missing, cannot initialize")
	--assert(humanRef, "Human reference missing from throwable class")
	local self = setmetatable({}, Throwable)
	local throwableData = ThrowableData[throwableName]
	self.Owner = humanRef
	self.Tool = tool or nil

	self.Name = throwableName
	self.Type = throwableData.Type
	self.CurrentAmmo = if ammo then ammo else throwableData.MaxAmmo
	self.MaxAmmo = throwableData.MaxAmmo
	self.DetonationTime = throwableData.DetonationTime
	self.FragmentCount = throwableData.FragmentCount
	self.FragmentDamage = throwableData.Damage
	self.FragmentType = throwableData.Type
	self.ThrowDelay = throwableData.ThrowDelay
	self.Damage = throwableData.Damage
	self.Velocity = throwableData.Velocity
	self.ImpactParticle = throwableData.ImpactParticle
	self.SpreadParticle = throwableData.SpreadParticle
	self.SpreadDuration = throwableData.SpreadDuration
	self.ThrowVelocity = throwableData.Velocity
	self.CanThrow = true
	self.Janitor = Janitor.new()
	self.ProjectileData = ThrowableData[self.Name].ProjectileData

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

	return self
end
function Throwable:UpdateAmmo(amount: number)
	if self.CurrentAmmo >= self.MaxAmmo then
		return false
	end
	self.CurrentAmmo = math.max(0, self.CurrentAmmo + amount)

	-- if self.CurrentAmmo <= 0 then
	-- 	self.Owner.Inventory:RemoveWeapon("Throwable")
	-- 	return false
	-- end

	return true
end

function Throwable:Throw(cameraLookVector: Vector3)
	if not self.CanThrow then
		return false
	end
	if self.CurrentAmmo <= 0 then
		self.Owner.Inventory:RemoveWeapon("Throwable")
		return false
	end

	self.CanThrow = false
	self.Tool.Handle.Transparency = 1
	local head = self.Owner.BodyParts["Head"]
	local launchPos = head.Position + Vector3.new(0, 2, 0)

	local context = ProjectileContext.BulletContext.new({
		Origin = launchPos,
		Direction = cameraLookVector,
		Speed = self.ThrowVelocity,
		RaycastParams = self.RaycastParams,
	})

	context.UserData.Class = self
	context.UserData.ProjectileType = "Throwable"
	context.UserData.Data = ThrowableData[self.Name]

	ProjectileContext.Solver:Fire(context, ThrowableData[self.Name].ProjectileData)

	local updated = self:UpdateAmmo(-1)
	if not updated then
		return false
	end

	-- cooldown for next throw
	task.delay(ThrowableData[self.Name].ThrowDelay, function()
		if not self then
			return
		end
		self.CanThrow = true

		if self.Tool and self.Tool:FindFirstChild("Handle") then
			self.Tool.Handle.Transparency = 0
		end
	end)

	return true
end

function Throwable:Destroy()
	self.Janitor:Destroy()
	self.Owner = nil
	setmetatable(self, nil)
	warn("Throwable class destroyed")
end

return Throwable
