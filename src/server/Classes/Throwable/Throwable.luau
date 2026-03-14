local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ThrowableSignals = require(script.Parent.ThrowableSignals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
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
	self.DetonationTime = ThrowableData[throwableName].DetonationTime
	self.ThrowForce = nil
	self.CanThrow = true
	self.Janitor = Janitor.new()

	self.FastCast = FastCast.new()
	self.ThrowVelocity = ThrowableData[throwableName].Velocity
	self.ProjectileData = FastCast.newBehavior()
	self.ProjectileData.RaycastParams = RaycastParams.new()
	self.ProjectileData.CosmeticBulletTemplate = nil
	self.ProjectileData.CosmeticBulletContainer = workspace.ProjectilesFolder
	self.ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.ProjectileData.RaycastParams.FilterDescendantsInstances = { humanRef.Character, self.Tool }
	self.ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	self.ProjectileData.AutoIgnoreContainer = true

	self:ConnectProjectileEvents()
	return self
end

function Throwable:Throw(cameraLookVector: Vector3)
	if not self.CanThrow then
		return false
	end
	self.CanThrow = false
	self.Tool.Handle.Transparency = 1
	self.CurrentAmmo = math.max(0, self.CurrentAmmo - 1)
	local rightHand = self.Owner.BodyParts["RightHand"]
	self.FastCast:Fire(rightHand.CFrame.Position, cameraLookVector, self.ThrowVelocity, self.ProjectileData)

	task.delay(ThrowableData[self.Name].ThrowDelay, function()
		self.CanThrow = true
		self.Tool.Handle.Transparency = 0
	end)

	return true
end

function Throwable:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _, cosmeticBulletObj)
		cosmeticBulletObj.Anchored = false
		task.delay(self.DetonationTime, function()
			local explosion: Explosion = Instance.new("Explosion")
			explosion.Parent = workspace
			explosion.BlastPressure = 0
			explosion.Position = cosmeticBulletObj.Position
			Debris:AddItem(explosion, 1)
			cosmeticBulletObj:Destroy()
		end)
	end))

	self.Janitor:Add(
		self.FastCast.LengthChanged:Connect(
			function(activeCast, lastPoint, rayDir, displacement, segmentVelocity, cosmeticBulletObj)
				local newPos = lastPoint + (rayDir * displacement)
				cosmeticBulletObj.Position = newPos
			end
		)
	)
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

		local projectileClone = self.Tool.Handle:Clone()
		projectileClone.Anchored = true

		self.ProjectileData.CosmeticBulletTemplate = projectileClone
		ThrowableSignals.ConnectThrowableSignal:Fire(self.Owner.Player, clone)
	end
end
return Throwable
