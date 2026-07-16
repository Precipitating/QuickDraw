local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NoobPath = require(ReplicatedStorage.Shared.Pathfinding.NoobPath)
local Path = require(ReplicatedStorage.Shared.Pathfinding.Path)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Dead = require(ServerScriptService.Server.Classes.AIBehaviour.States.Dead)
local Idle = require(ServerScriptService.Server.Classes.AIBehaviour.States.Idle)
local Seek = require(ServerScriptService.Server.Classes.AIBehaviour.States.Seek)

local StateMachine = require(script.Parent.StateMachine)

local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

type Human = ClassTypes.Human
type AgentParams = Path.AgentParams
type Animal = ClassTypes.Animal

local AI = {}
AI.__index = AI

function AI.new(owner: Human | Animal, classType: string)
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
	warn("AI base class called StateChangeReset")
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
		for _, partName in
			{ "Head", "UpperTorso", "Torso", "HumanoidRootPart", "RightUpperArm", "LeftUpperArm", "Body" }
		do
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
function AI:OrientTowards(seekDir: Vector3)
	local torsoAimer: AlignOrientation = self.Owner.TorsoAimer

	if not torsoAimer then
		warn("[AI:TweenTowardsSeekDir] Torso aimer missing!")
		return false
	end

	local flat = Vector3.new(seekDir.X, 0, seekDir.Z).Unit
	local hrp = self.Owner.HRP
	local goal = CFrame.lookAt(hrp.Position, hrp.Position + flat)

	torsoAimer.CFrame = goal

	torsoAimer.Enabled = true
	repeat
		task.wait()
	until not self.HRP or Utility.IsVectorNear(self.HRP.AssemblyAngularVelocity, 0.05)
	torsoAimer.Enabled = false

	return true
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

function AI:Attack()
	warn("Base class AI Attack() Called!")
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

-- Helper: raycast downward to snap candidate to ground level
function AI:GetGroundY(pos: Vector3): number?
	local origin = Vector3.new(pos.X, pos.Y + 50, pos.Z)
	local direction = Vector3.new(0, -200, 0)
	local result = workspace:Raycast(origin, direction, self.RaycastParams)
	if result then
		return result.Position.Y
	end
	return nil
end

-- Find a valid position around target (circular around)
-- It only returns positions that the the AI will have a line of sight to
function AI:FindAnglePosition(
	originPos: Vector3,
	target: Model | BasePart,
	customPosition: Vector3?,
	radius: number,
	recursing: boolean
): Vector3?
	local targetPos: Vector3

	if customPosition then
		targetPos = customPosition
	else
		if typeof(target) == "Instance" then
			if target:IsA("Model") then
				targetPos = target:GetPivot().Position
			elseif target:IsA("BasePart") then
				targetPos = (target :: BasePart).Position
			else
				return nil
			end
		end
	end

	local baseDir = (originPos - targetPos)
	-- Flatten to XZ for rotation, but preserve a reference Y
	local baseDirFlat = Vector3.new(baseDir.X, 0, baseDir.Z)
	if baseDirFlat.Magnitude < 0.001 then
		baseDirFlat = Vector3.new(1, 0, 0) -- fallback if directly above/below
	end
	baseDirFlat = baseDirFlat.Unit

	local bestCandidate: Vector3? = nil
	local bestScore = math.huge

	-- Two-pass: coarse then fine around best coarse hit
	local function evaluateCandidates(angleList: { number })
		for _, angle in ipairs(angleList) do
			local radians = math.rad(angle)
			local cos, sin = math.cos(radians), math.sin(radians)
			local rotated =
				Vector3.new(baseDirFlat.X * cos - baseDirFlat.Z * sin, 0, baseDirFlat.X * sin + baseDirFlat.Z * cos)

			-- Raycast downward to find ground Y so the candidate sits on terrain
			local candidateXZ = targetPos + rotated * radius
			local groundY = self:GetGroundY(candidateXZ) or targetPos.Y
			local candidate = Vector3.new(candidateXZ.X, groundY, candidateXZ.Z)

			if self:IsTargetInView(candidate, target, false) then
				-- Score: weighted sum of distance to origin + distance to target (prefer mid-range)
				local distToOrigin = (originPos - candidate).Magnitude
				local distToTarget = (targetPos - candidate).Magnitude
				-- Penalise straying far from the requested radius
				local radiusDrift = math.abs(distToTarget - radius)
				local score = distToOrigin + radiusDrift * 0.5

				if score < bestScore then
					bestScore = score
					bestCandidate = candidate
				end
			end
		end
	end

	-- Pass 1: coarse sweep every 15°
	local coarseAngles = {}
	for angle = 0, 359, 15 do
		table.insert(coarseAngles, angle)
	end
	evaluateCandidates(coarseAngles)

	-- Pass 2: fine sweep 15° around best coarse result in 3° steps
	if bestCandidate then
		local bestAngle = math.deg(math.atan2(bestCandidate.Z - targetPos.Z, bestCandidate.X - targetPos.X))
		local fineAngles = {}
		for offset = -15, 15, 3 do
			table.insert(fineAngles, bestAngle + offset)
		end
		evaluateCandidates(fineAngles)
	end

	if bestCandidate then
		return bestCandidate
	end

	-- Radius expansion with early-out
	if recursing then
		return nil
	end

	for _ = 1, 6 do
		radius *= 1.25
		local candidate = self:FindAnglePosition(originPos, target, customPosition, radius, true)
		if candidate then
			return candidate
		end
	end

	return nil
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
