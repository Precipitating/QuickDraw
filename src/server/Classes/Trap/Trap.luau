local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanRegistry = require(ServerScriptService.Server.Classes.Human.HumanRegistry)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local ProjectileContext = require(script.Parent.Parent.Parent.ProjectilesHandler.ProjectileContext)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local TrapPlaceables = ReplicatedStorage.Shared.Templates.Traps

local TRAP_PLACE_STUDS_FORWARD = 5
local TRAP_PLACE_STUDS_DOWN = 10

local function TrapPlacementHasRoof(
	origin: Vector3,
	checkDist: number,
	exclusion: RaycastParams?
): (boolean, RaycastResult?)
	-- Check if placeable, needs to have a roof
	local hasRoof = workspace:Raycast(origin, Vector3.new(0, checkDist, 0), exclusion)

	-- Temporary Debug Line
	-- local debugPart = Instance.new("Part")
	-- debugPart.Anchored = true
	-- debugPart.CanCollide = false
	-- debugPart.Color = Color3.fromRGB(255, 0, 0)
	-- debugPart.Size = Vector3.new(0.2, checkDist, 0.2)
	-- debugPart.CFrame = CFrame.new(origin + Vector3.new(0, checkDist / 2, 0))
	-- debugPart.Parent = workspace
	-- game:GetService("Debris"):AddItem(debugPart, 10) -- Disappears after 2 seconds

	if not hasRoof then
		return false, nil
	end

	-- Ensure the height from  place pos to wall isn't small
	local isAcceptableHeight = hasRoof.Distance >= 5

	if not isAcceptableHeight then
		return false, nil
	end

	return true, hasRoof
end

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

	RopeTrap = function(
		trapOwner: ClassTypes.Human,
		trapModel: Model,
		hitPart: BasePart | MeshPart,
		hitHuman: Human,
		trapData
	)
		if not trapModel or not hitHuman or not trapData then
			return
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { trapModel }
		local canPlace, raycastResult =
			TrapPlacementHasRoof(trapModel:GetPivot().Position, trapData.CeilingDistance, raycastParams)
		if not canPlace then
			return
		end

		-- 1 Connect rope from ceiling to hit player part
		local trapDuration = trapData.Duration
		-- 1.1 Define hit part attachment
		-- Limb should have an attachment already, doesn't matter which
		local limbAttachment = hitPart:FindFirstChildOfClass("Attachment")
		if not limbAttachment then
			warn("[RopeTrap] Limb or hit part has no attachment")
			return
		end

		-- 1.2 Define ceiling attachment
		local ceilingPos = raycastResult.Position
		local ceiling = raycastResult.Instance
		local ceilingAttachment = Instance.new("Attachment")

		ceilingAttachment.CFrame = ceiling.CFrame:ToObjectSpace(CFrame.new(ceilingPos))
		ceilingAttachment.Parent = ceiling

		-- 2 Create rope constraint and attach
		local rope = Instance.new("RopeConstraint")
		rope.Attachment0 = ceilingAttachment
		rope.Attachment1 = limbAttachment
		rope.Visible = true
		rope.Length = raycastResult.Distance * 0.6
		rope.Parent = ceiling
		rope.Color = BrickColor.new(Color3.fromRGB(142, 77, 165))

		local activateSound = trapData.TrapActivatedSoundName
		ServerSoundHandler:Play3DOneShotToOthers(nil, activateSound, hitPart.CFrame)

		if trapModel then
			trapModel:Destroy()
		end

		-- 3 Ragdoll & destroy
		hitHuman:Ragdoll(trapDuration)
		task.delay(trapDuration, function()
			rope:Destroy()
			ceilingAttachment:Destroy()
		end)
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

function Trap:CanPlace(placePos: Vector3)
	if self.Name == "RopeTrap" then
		local canPlace, _ = TrapPlacementHasRoof(placePos, TrapData["RopeTrap"].CeilingDistance)
		return canPlace
	end

	return true
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

	-- 1.5 Check if can place first
	local canPlace = self:CanPlace(placeRay.Position)

	if not canPlace then
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

	-- 2.2 Place trap
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
