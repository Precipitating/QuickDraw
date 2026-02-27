local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local Human = require(ServerScriptService.Server.Classes.Human.Human)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local Throwable = {}
type Human = ClassTypes.Human
Throwable.__index = Throwable

function Throwable.new(throwableName: string, humanRef: Human)
	assert(ThrowableData[throwableName], "Throwable name missing, cannot initialize")
	assert(humanRef, "Human reference missing from throwable class")
	local self = setmetatable({}, Throwable)
	self.Owner = humanRef
	self.Name = throwableName
	self.Tool = nil
	self.CurrentAmmo = ThrowableData[throwableName].MaxAmmo
	self.DetonationTime = GunData[throwableName].DetonationTime
	self.ThrowForce = nil
	self.Janitor = Janitor.new()

	self.FastCast = FastCast.new()
	self.ThrowVelocity = ThrowableData[throwableName].Velocity
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.CosmeticBulletTemplate = self.Tool.Handle
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { humanRef.Character, self.Tool }
	self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	self.ProjectileData.AutoIgnoreContainer = true

	Throwable:ConnectProjectileEvents()
	return self
end

function Throwable:Throw()
	self.CurrentAmmo = math.max(0, self.CurrentAmmo - 1)

	self.FastCast:Fire(
		self.Bodyparts["RightHand"].CFrame.Position,
		self.Bodyparts["RightHand"].CFrame.LookVector,
		self.ThrowVelocity,
		self.ProjectileData
	)
end

function Throwable:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _)
		task.delay(self.DetonationTime, function() end)
	end))
end

function Throwable:Remove()
	if self.Owner.HumanType == "Player" then
		self.Owner.Player.Backpack:FindFirstChild(self.Name):Destroy()
	else
		-- HumanNPC
		self.Owner:UnEquipCurrentTool()
	end
end

function Throwable:AddThrowableToInventory()
	local clone: Tool = ServerStorage.Templates:FindFirstChild(self.Name):Clone()
	self.Tool = clone

	if self.Owner.HumanType == "Player" then
		clone.Parent = self.Owner.Player.Backpack
		self.Janitor:Add(self.Tool)
	end
end
return Throwable
