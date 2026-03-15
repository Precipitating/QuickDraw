local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ThrowableSignals = require(script.Parent.ThrowableSignals)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Throwable = {}
type Human = ClassTypes.Human
Throwable.__index = Throwable

local fragmentParam = RaycastParams.new()
fragmentParam.FilterType = Enum.RaycastFilterType.Exclude

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

	if self.CurrentAmmo == 0 then
		self:Remove()
	end

	task.delay(ThrowableData[self.Name].ThrowDelay, function()
		self.CanThrow = true

		if self.Tool and self.Tool:FindFirstChild("Handle") then
			self.Tool.Handle.Transparency = 0
		end
	end)

	return true
end

function Throwable:SpawnFragments(spawnPos: Vector3)
	local normal = Vector3.new(0, 1, 0)
	local fragmentCount = ThrowableData[self.Name].FragmentCount
	local fragmentRange = ThrowableData[self.Name].FragmentRange
	local fragmentDamage = ThrowableData[self.Name].Damage

	for _ = 1, fragmentCount do
		local dir = RandomModule.GetNextUnitVector()

		-- inverse if hits ground, creating a hemisphere
		if dir:Dot(normal) < 0 then
			dir = -dir
		end

		local hit = workspace:Raycast(spawnPos, dir * fragmentRange)

		if hit then
			local hitInstance = hit.Instance
			if hitInstance:FindFirstAncestorOfClass("Accessory") then
				continue
			end

			-- damage bodyparts if hits player
			local isModel = hitInstance:FindFirstAncestorOfClass("Model")
			if isModel then
				local humanoid = isModel:FindFirstChild("Humanoid")
				if humanoid then
					GunSignals.PlayerHit:Fire(hit, humanoid, fragmentDamage)
				end
			end
		end

		-- local debugPart = Instance.new("Part")
		-- debugPart.CanCollide = false
		-- debugPart.CanTouch = false
		-- debugPart.CanQuery = false
		-- debugPart.CFrame = CFrame.lookAt(spawnPos, spawnPos + dir) * CFrame.new(0, 0, -fragmentRange / 2)
		-- debugPart.Size = Vector3.new(0.1, 0.1, fragmentRange)
		-- debugPart.Parent = workspace
	end
end

function Throwable:ConnectProjectileEvents()
	self.Janitor:Add(self.FastCast.RayHit:Connect(function(_, raycastResult: RaycastResult, _, cosmeticBulletObj)
		cosmeticBulletObj.Anchored = false

		ServerSoundHandler:Play3DOneShotToOthers(nil, ThrowableData[self.Name].LandSound, cosmeticBulletObj.CFrame)
		task.delay(self.DetonationTime, function()
			local cosmeticPos = cosmeticBulletObj.Position
			local explosion: Explosion = Instance.new("Explosion")
			explosion.Parent = workspace
			explosion.BlastPressure = 0
			explosion.Position = cosmeticBulletObj.Position
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				ThrowableData[self.Name].DetonationSound,
				cosmeticBulletObj.CFrame,
				{ MaxDistance = 150 }
			)

			Debris:AddItem(explosion, 0.5)
			Debris:AddItem(cosmeticBulletObj, 0.5)
			self:SpawnFragments(cosmeticPos)
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
		local toolInInventory = self.Owner.Player.Backpack:FindFirstChild(self.Name)
		local toolInHands = Utility.GetInstance(self.Owner.Player.Character, false, self.Name)
		if toolInInventory then
			toolInInventory:Destroy()
			return
		end

		if toolInHands then
			toolInHands:Destroy()
		end
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
