local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanRegistry = require(ServerScriptService.Server.Classes.Human.HumanRegistry)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local ProjectileContext = require(ServerScriptService.Server.ProjectilesHandler.ProjectileContext)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local TrapPlaceables = ReplicatedStorage.Shared.Templates.Traps

local TRAP_PLACE_STUDS_FORWARD = 5
local TRAP_PLACE_STUDS_DOWN = 10
local TrapActivatedLogic = {
	BearTrap = function(
		_: ClassTypes.Human?,
		trapModel: Model?,
		hitPart: BasePart | MeshPart,
		hitHuman: Human,
		trapData
	)
		local activateSound = trapData.TrapActivatedSoundName
		ServerSoundHandler:Play3DOneShotToOthers(nil, activateSound, hitPart.CFrame)

		local data = {
			Damage = trapData.Damage,
			LimbHit = hitPart,
			TargetHuman = hitHuman,
			CanAffectShooter = false,
		} :: ClassTypes.TrapDamage

		DamageModule.DamageHuman(data)

		hitHuman:Ragdoll(5)

		if trapModel then
			trapModel:Destroy()
		end
	end,

	TripMine = function(
		trapOwner: ClassTypes.Human,
		trapModel: BasePart,
		hitPart: BasePart | MeshPart,
		hitHuman: Human,
		trapData
	)
		local activateSound = trapData.TrapActivatedSoundName
		local explosiveData = ThrowableData[trapData.AttachedExplosive]
		if not explosiveData then
			warn("Tripmine missing explosive data")
			return
		end
		ServerSoundHandler:Play3DOneShotToOthers(nil, activateSound, hitPart.CFrame)

		local context = ProjectileContext.BulletContext.new({
			Origin = trapModel:GetPivot().Position + Vector3.new(0, 1, 0),
			Direction = -Vector3.yAxis,
			Speed = explosiveData.Velocity,
			RaycastParams = explosiveData.RaycastParams,
		})

		context.UserData.Class = { Owner = trapOwner }
		context.UserData.ProjectileType = "Throwable"
		context.UserData.Data = explosiveData

		ProjectileContext.Solver:Fire(context, explosiveData.ProjectileData)

		if trapModel then
			trapModel:Destroy()
		end
	end,
}
local Trap = {}
Trap.__index = Trap

type Human = ClassTypes.Human

function Trap.new(trapName: string, humanRef: Human, ammo: number?, tool: Tool?)
	assert(humanRef, "Trap class initialization failed: Missing inventory ref")
	assert(tool, "Missing tool ref for new trap class")
	local self = setmetatable({}, Trap)
	local trapData = TrapData[trapName]
	if not trapData then
		warn("Trap class initialization failed: Trap name is invalid")
		return
	end
	self.Janitor = Janitor.new()
	self.Name = trapName
	self.Tool = self.Janitor:Add(tool)
	self.Damage = trapData.Damage
	self.CurrentAmmo = if ammo then ammo else trapData.MaxAmmo
	self.MaxAmmo = trapData.MaxAmmo
	self.Disguised = trapData.Disguise or false

	self.Owner = humanRef
	return self
end

function Trap:UpdateAmmo(amount: number)
	if amount > 0 and self.CurrentAmmo >= self.MaxAmmo then
		return false
	end
	self.CurrentAmmo = math.max(0, self.CurrentAmmo + amount)
	if self.CurrentAmmo <= 0 then
		self.Owner.Inventory:RemoveWeapon("Trap")
	end
	return true
end

function Trap:Destroy()
	self.Janitor:Cleanup()

	self.Tool = nil
	self.Owner = nil
	self.Name = nil
	self.Damage = nil
	self.CurrentAmmo = nil
	self.MaxAmmo = nil

	setmetatable(self, nil)
	table.clear(self)
end

function Trap:ConnectTrap(trapCollider: BasePart)
	local trapName = self.Name
	if not trapCollider or not trapName then
		warn("[ConnectTrap] a parameter is nil")
		return
	end

	local trapData = TrapData[trapName]
	if not trapData then
		warn("[ConnectTrap] Trap name is not valid ")
		return
	end

	local trapOwner = self.Owner
	local hitCollisionConn = nil
	hitCollisionConn = trapCollider.Touched:Connect(function(hitPart: BasePart)
		if not TrapActivatedLogic[trapName] then
			return
		end

		local hitParent = hitPart and hitPart.Parent
		if not hitParent then
			return
		end

		local hitHumanoid = hitParent:FindFirstChild("Humanoid")

		if not hitHumanoid then
			return
		end

		local hitHuman = HumanRegistry:Get(hitHumanoid)

		if not hitHuman then
			warn("Trap cannot activate, whatever triggered has no human class")
			return
		end

		TrapActivatedLogic[trapName](trapOwner, trapCollider.Parent, hitPart, hitHuman, trapData)
		hitCollisionConn:Disconnect()
	end)
end

function Trap:Place()
	if not self.Tool then
		return
	end

	local character = self.Owner.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return false
	end

	-- Use HRP as raycast origin for consistency and no reliance on physics
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	-- 1.
	-- Define raycast origin
	local rayCastPosition = hrp.Position + (hrp.CFrame.LookVector * TRAP_PLACE_STUDS_FORWARD)

	local placeRay = workspace:Raycast(rayCastPosition, -Vector3.yAxis * TRAP_PLACE_STUDS_DOWN)

	if not placeRay and self.Owner.Player then
		return false
	end

	-- 2. Clone template and place on floor
	local template = TrapPlaceables:FindFirstChild(`{self.Name}Placed`)

	if not template then
		return false
	end

	template = template:Clone()

	-- 2.1 Blend trap to environment if diguised = true
	if self.Disguised then
		if template:IsA("BasePart") then
			template.Material = placeRay.Instance.Material
			template.BrickColor = placeRay.Instance.BrickColor
		end
	end

	-- 2.2 Ensure not moving when placing
	if template:IsA("Model") then
		template:PivotTo(CFrame.new(placeRay.Position))
	else
		template.Position = placeRay.Position
	end
	template.Parent = workspace

	-- 3 Enable trap functionality
	self:ConnectTrap(template:FindFirstChild("Collision") or template)

	self:UpdateAmmo(-1)

	return true
end

return Trap
