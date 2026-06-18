local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local NoobPath = require(ReplicatedStorage.Shared.Pathfinding.NoobPath)
local Path = require(ReplicatedStorage.Shared.Pathfinding.Path)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Dead = require(ServerScriptService.Server.Classes.AIBehaviour.States.Dead)
local Idle = require(ServerScriptService.Server.Classes.AIBehaviour.States.Idle)
local Seek = require(ServerScriptService.Server.Classes.AIBehaviour.States.Seek)

local StateMachine = require(script.Parent.StateMachine)

local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

type Human = ClassTypes.Human
type AgentParams = Path.AgentParams

local AI = {}
AI.__index = AI

function AI.new(owner: Human, classType: string)
	local self = setmetatable({}, AI)
	assert(owner, "Owner incorrect for AI class initialization")
	self.Type = nil
	self.Owner = owner
	self.StateMachine = StateMachine.new()
	self.EnemyList = {}
	self.AttackState = { Name = "", Data = nil }
	self.DefaultState = { Name = "", Data = nil }
	self.WeaponName = nil
	self.ThrowableName = nil
	self.ThrowableAmmo = nil
	self.SeekTurnDelay = 0.5
	self.NoobPath = NoobPath.Humanoid(
		self.Owner.Character,
		{ WaypointSpacing = 10, AgentRadius = 3, PathSettings = { SupportPartialPath = true } } :: AgentParams
	)
	self.NoobPath.Visualize = false
	self.NoobPath.Timeout = true
	self.NoobPath.Speed = HumanConstants.WALKSPEED
	self.MinAttackDistance = 0
	self.MaxAttackDistance = 0
	self.EyeRange = 0

	self:Initialize()

	return self
end

function AI:ChangeWalkSpeed(walkspeed: number)
	self.Owner.Humanoid.WalkSpeed = walkspeed
	self.NoobPath.Speed = walkspeed
end

-- Initialize state machine states
function AI:Initialize()
	self.StateMachine:AddState("Idle", Idle.new(self.StateMachine, self))
	self.StateMachine:AddState("Seek", Seek.new(self.StateMachine, self))
	self.StateMachine:AddState("Dead", Dead.new(self.StateMachine, self))

	self.NoobPath.Trapped:Connect(function()
		if self.Owner.Humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then -- Climbing is slower than usual
			self.NoobPath.Jump() -- Jump to unstuck
		end
		self.NoobPath:Run()
	end)

	self.NoobPath.Error:Connect(function()
		warn("[SERVER] NPC errored on pathfinding, defaulting to default state")
		self.StateMachine:Transition(self.DefaultState.Name, self.DefaultState.Data)
	end)
end

function AI:StopPathfind()
	if not self.Owner or self.Owner.Dead then
		return
	end
	if self and self.NoobPath then
		self.NoobPath:Stop()
	end
end

function AI:Destroy()
	self.NoobPath:Destroy()
end

function AI:StateChangeReset()
	self.Owner:ToggleRightArmAimer(false)
	self.Owner:ToggleTorsoAimer(false)
	self:ChangeWalkSpeed(HumanConstants.WALKSPEED)

	self:StopPathfind()
end

function AI:IsTargetInView(originPos: Vector3, target: BasePart | Model, useFOV: boolean)
	local targetPos: Vector3
	local targetAncestor: Instance? = nil

	if typeof(target) == "Instance" then
		if target:IsA("Model") then
			targetPos = target:GetPivot().Position
			targetAncestor = target
		elseif target:IsA("BasePart") then
			targetPos = target.Position
			targetAncestor = target:FindFirstAncestorOfClass("Model") or target
		else
			warn("AI:IsTargetInView - Unsupported instance type:", target.ClassName)
			return false
		end
	else
		warn("AI:IsTargetInView - Invalid target type:", typeof(target))
		return false
	end

	local direction = targetPos - originPos
	local distance = direction.Magnitude

	if distance > self.EyeRange then
		return false
	end

	local dirUnit = direction.Unit

	-- ── FOV Check ────────────────────────────────
	if useFOV then
		local fov = 120
		local head = self.Owner and self.Owner.BodyParts and self.Owner.BodyParts["Head"]
		if head then
			local lookDir = head.CFrame.LookVector
			local halfFOV = math.rad(fov / 2)
			local dot = lookDir:Dot(dirUnit)
			local angle = math.acos(math.clamp(dot, -1, 1))

			if angle > halfFOV then
				return false
			end
		end
	end

	-- ── Raycast (multi-point) ──────────────────────────────────

	local filterList = { self.Owner.Character }

	-- When originPos is a candidate position (not on a character), we don't need
	-- extra filtering beyond the AI's own character. But if the origin is inside
	-- the AI's character, we already exclude it above.
	raycastParams.ExcludeInstances = filterList

	-- Build check points — start with targetPos, add body parts if available
	local checkPoints = { targetPos }

	if targetAncestor then
		for _, partName in { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "RightUpperArm", "LeftUpperArm" } do
			local part = targetAncestor:FindFirstChild(partName)
			if part and part:IsA("BasePart") then
				-- Avoid duplicates when targetPos already matches one of these
				local pos = part.Position
				if (pos - targetPos).Magnitude > 0.5 then
					table.insert(checkPoints, pos)
				end
			end
		end
	end

	for _, point in checkPoints do
		local dir = point - originPos
		local dist = dir.Magnitude

		if dist < 0.01 then
			return true
		end

		local result = workspace:Raycast(originPos, dir.Unit * dist, raycastParams)

		-- Nothing hit = clear line of sight
		if not result then
			return true
		end

		-- Something hit — check if it belongs to the target
		if targetAncestor then
			if result.Instance:IsDescendantOf(targetAncestor) or result.Instance == targetAncestor then
				return true
			end
		end
	end

	return false
end

function AI:AlignOrientLookAround()
	local torsoAimer = self.Owner.TorsoAimer

	if not torsoAimer then
		warn("[AI:AlignOrientLookAround] Missing torso aimer reference")
		return false
	end

	local foundTargetModel = self:CheckSurroundingsForEnemy()
	if foundTargetModel then
		return foundTargetModel
	end

	for _ = 1, 6 do
		torsoAimer.CFrame *= CFrame.Angles(0, math.rad(60), 0)
		task.wait(self.SeekTurnDelay)
		if not self.Owner or not self.Owner.TorsoAimer then
			return false
		end

		foundTargetModel = self:CheckSurroundingsForEnemy()
		if foundTargetModel then
			return foundTargetModel
		end
	end

	return false
end
function AI:OrientTowardsSeekDir(seekDir: Vector3)
	local torsoAimer: AlignOrientation = self.Owner.TorsoAimer

	if not torsoAimer then
		warn("[AI:TweenTowardsSeekDir] Torso aimer missing!")
	end
	local flat = Vector3.new(seekDir.X, 0, seekDir.Z).Unit
	local hrp = self.Owner.HRP
	local goal = CFrame.lookAt(hrp.Position, hrp.Position + flat)

	torsoAimer.CFrame = goal
	repeat
		task.wait()
	until not self.HRP or Utility.IsVectorNear(self.HRP.AssemblyAngularVelocity, 0.05)
	task.wait(2)
	local foundTargetModel = self:CheckSurroundingsForEnemy()
	if foundTargetModel then
		return foundTargetModel
	end
	return false
end

-- look in 4 directions and attempt to find an enemy, prompting 'Attack' state if so.
function AI:LookAround()
	if not self.Owner then
		return nil
	end
	local targetFound = nil

	self:StateChangeReset()
	self.Owner:ToggleTorsoAimer(true)
	warn("Toggled torso")

	targetFound = self:AlignOrientLookAround()

	if type(self.Owner.ToggleTorsoAimer) ~= "function" then
		return nil
	end
	self.Owner:ToggleTorsoAimer(false)
	return targetFound
end

-- Check if target has a tag that is considered an enemy to the AI
function AI:TargetIsEnemy(target)
	local targetTags = CollectionService:GetTags(target)

	for _, tag in targetTags do
		if self.EnemyList[tag] then
			return true
		end
	end

	return false
end

-- Get angle required for object to hit a position (if possible)
function AI:GetThrowAngle(origin, target, velocity)
	local diff = target - origin
	local horizontalDist = Vector3.new(diff.X, 0, diff.Z).Magnitude
	local verticalDist = diff.Y
	local v2 = velocity * velocity
	local g = workspace.Gravity

	local discriminant = v2 * v2 - g * (g * horizontalDist * horizontalDist + 2 * verticalDist * v2)
	if discriminant < 0 then
		return nil, nil -- target out of range for this velocity
	end

	-- two solutions, low arc and high arc
	local lowArc = math.atan((v2 - math.sqrt(discriminant)) / (g * horizontalDist))
	local highArc = math.atan((v2 + math.sqrt(discriminant)) / (g * horizontalDist))

	return lowArc, highArc -- in radians
end
function AI:ThrowThrowable(targetPos)
	local throwable = self.Owner.Inventory:GetThrowable()
	if not throwable then
		return false
	end
	if throwable.CurrentAmmo <= 0 then
		return false
	end

	local origin = self.Owner.BodyParts["RightHand"].Position

	local lowArc, _ = self:GetThrowAngle(origin, targetPos, throwable.Velocity)
	if not lowArc then
		return false
	end

	local toTargetDir = (targetPos - origin).Unit
	local throwDirection = (CFrame.new(Vector3.zero, toTargetDir) * CFrame.Angles(lowArc, 0, 0)).LookVector

	local thrown = throwable:Throw(throwDirection)
	return thrown
end

function AI:CheckSurroundingsForEnemy()
	local foundParts = self:CheckLineOfSight()
	if not foundParts then
		return false
	end

	for _, part in foundParts do
		if not part or not part:IsA("MeshPart") then
			continue
		end

		local parent = part.Parent
		local hrp = parent and parent:FindFirstChild("HumanoidRootPart")
		local humanoid = parent and parent:FindFirstChild("Humanoid")

		if CollectionService:HasTag(parent, "Dead") then
			continue
		end

		if not hrp or not humanoid or not self:TargetIsEnemy(parent) then
			continue
		end

		local head = self.Owner and self.Owner.BodyParts and self.Owner.BodyParts["Head"]
		if not head then
			continue
		end

		local visible = self:IsTargetInView(head.Position, hrp, true)
		if not visible then
			continue
		end

		return parent or false
	end

	return false
end

function AI:CheckLineOfSight()
	if not self.Owner then
		return
	end
	if not self.Owner.HRP then
		return
	end

	local hrp = self.Owner.HRP.Position
	local LineOfSightParams = OverlapParams.new()
	LineOfSightParams.ExcludeInstances = { self.Owner.Character }

	local foundParts = workspace:GetPartBoundsInRadius(hrp, self.EyeRange)
	return foundParts
end
function AI:PathFindTo(targetPos: Vector3)
	if self.Owner.IsRagdolled then
		return
	end

	self.NoobPath:Run(targetPos)
end

return AI
