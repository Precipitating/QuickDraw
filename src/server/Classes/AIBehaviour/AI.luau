local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")

local ServerScriptService = game:GetService("ServerScriptService")

local Dead = require(ServerScriptService.Server.Classes.AIBehaviour.States.Dead)
local Idle = require(ServerScriptService.Server.Classes.AIBehaviour.States.Idle)
local Seek = require(ServerScriptService.Server.Classes.AIBehaviour.States.Seek)
local AISignals = require(script.Parent.AISignals)

local StateMachine = require(script.Parent.StateMachine)

local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

type Human = ClassTypes.Human

local AI = {}
AI.__index = AI

function AI.new(owner: Human)
	local self = setmetatable({}, AI)
	assert(owner, "Owner incorrect for AI class initialization")
	self.Type = nil
	self.TypeInfo = nil
	self.Owner = owner
	self.StateMachine = StateMachine.new()
	self.CurrentlyMoving = false
	self.PatrolPoints = nil
	self.EnemyList = { Player = true }
	self.AttackStateName = ""

	self.NextWaypointIndex = nil
	self.SeekTurnDelay = 1
	self.ReachedConnection = nil
	self.BlockedConnection = nil

	self.PathfindTolerance = 2
	self.MinAttackDistance = 0
	self.MaxAttackDistance = 0

	--self:EnableEnemyDetection()
	self:Initialize()

	return self
end

-- Initialize state machine states
function AI:Initialize()
	self.StateMachine:AddState("Idle", Idle.new(self.StateMachine, self))
	self.StateMachine:AddState("Seek", Seek.new(self.StateMachine, self))

	self.StateMachine:AddState("Dead", Dead.new(self.StateMachine, self))
end

function AI:StateChangeReset()
	self:CancelPathFind()
	self.Owner:ToggleRightArmAimer(false)
	self.Owner:ToggleTorsoAimer(false)

	if self.ReachedConnection then
		self.ReachedConnection:Disconnect()
		self.ReachedConnection = nil
	end
	if self.BlockedConnection then
		self.BlockedConnection:Disconnect()
		self.BlockedConnection = nil
	end
end

function AI:CancelPathFind()
	self.Owner.Humanoid:MoveTo(self.Owner.HRP.Position)
	self.CurrentlyMoving = false
end

function AI:IsTargetInView(originPos: Vector3, target: BasePart | Model | Vector3, useFOV: boolean)
	local targetPos: Vector3
	local targetAncestor: Instance? = nil

	if typeof(target) == "Vector3" then
		targetPos = target
	elseif typeof(target) == "Instance" then
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

	if distance > self.MaxAttackDistance then
		return false
	end

	if distance < 0.01 then
		return true
	end

	local dirUnit = direction.Unit

	-- ── FOV Check ────────────────────────────────
	if useFOV then
		local fov = 120
		local head = self.Owner.BodyParts["Head"]
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
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local filterList = { self.Owner.Character }

	-- When originPos is a candidate position (not on a character), we don't need
	-- extra filtering beyond the AI's own character. But if the origin is inside
	-- the AI's character, we already exclude it above.
	raycastParams.FilterDescendantsInstances = filterList

	-- Build check points — start with targetPos, add body parts if available
	local checkPoints = { targetPos }

	if targetAncestor then
		for _, partName in { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } do
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

	for _ = 1, 3 do
		torsoAimer.CFrame *= CFrame.Angles(0, math.rad(45), 0)
		task.wait(1)
		local foundTargetModel = self:CheckSurroundingsForEnemy()
		if foundTargetModel then
			return foundTargetModel
		end
	end
	return false
end
function AI:TweenTowardsSeekDir(seekDir: Vector3)
	local torsoAimer: AlignOrientation = self.Owner.TorsoAimer

	if not torsoAimer then
		warn("[AI:TweenTowardsSeekDir] Torso aimer missing!")
	end
	local flat = Vector3.new(seekDir.X, 0, seekDir.Z).Unit
	local hrp = self.Owner.HRP
	local goal = CFrame.lookAt(hrp.Position, hrp.Position + flat)
	torsoAimer.CFrame = goal
	task.wait(0.5)
	local foundTargetModel = self:CheckSurroundingsForEnemy()
	if foundTargetModel then
		return foundTargetModel
	end
	return false
end

-- look in 4 directions and attempt to find an enemy, prompting 'Attack' state if so.
function AI:LookAround(seekDir: Vector3)
	local targetFound = nil

	if self.CurrentlyMoving then
		self:CancelPathFind()
	end

	if seekDir then
		targetFound = self:TweenTowardsSeekDir(seekDir)
	end
	if not targetFound then
		targetFound = self:AlignOrientLookAround()
	end

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
	local throwable = self.Owner.CurrentThrowable
	if throwable.CurrentAmmo <= 0 then
		return false
	end
	local rightHand = self.Owner.BodyParts["RightHand"]
	local toTargetDir = (targetPos - rightHand.Position).Unit

	local hrpPos = self.Owner.HRP.Position
	local lowArc, _ = self:GetThrowAngle(hrpPos, targetPos, throwable.Velocity)

	if not lowArc then
		return false
	end

	local throwDirection = (CFrame.new(Vector3.zero, toTargetDir) * CFrame.Angles(lowArc, 0, 0)).LookVector

	throwable:Throw(throwDirection)
	return true
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
	LineOfSightParams.FilterType = Enum.RaycastFilterType.Exclude
	LineOfSightParams.FilterDescendantsInstances = { self.Owner.Character }

	local foundParts = workspace:GetPartBoundsInRadius(hrp, self.MaxAttackDistance)
	return foundParts
end
function AI:PathFindTo(targetPos: Vector3)
	self:StateChangeReset()

	if self.Owner.IsRagdolled then
		return
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		PathSettings = {
			SupportPartialPath = true,
		},
	})
	local character = self.Owner.Character
	local humanoid: Humanoid = self.Owner.Humanoid

	if not character or not humanoid then
		return
	end

	local success, errorMessage = pcall(function()
		path:ComputeAsync(character:GetPivot().Position, targetPos)
	end)

	if not success then
		warn(`AI failed to pathfind: {errorMessage}`)
		return
	end

	if path.Status == Enum.PathStatus.Success or path.Status == Enum.PathStatus.ClosestNoPath then
		self.Owner:ToggleRightArmAimer(false)
		self.CurrentlyMoving = true
		local waypoints = path:GetWaypoints()

		-- Clean up old connections before creating new ones
		if self.BlockedConnection then
			self.BlockedConnection:Disconnect()
			self.BlockedConnection = nil
		end
		if self.ReachedConnection then
			self.ReachedConnection:Disconnect()
			self.ReachedConnection = nil
		end

		-- Detect if path becomes blocked
		self.BlockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
			if blockedWaypointIndex >= self.NextWaypointIndex then
				print("Waypoint blocked, trying again with an offset")
				local angle = math.random() * math.pi * 2
				local radius = 6
				local randomOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
				self:PathFindTo(targetPos + randomOffset)
			end
		end)

		-- Start at index 2 (index 1 is the character's current position)
		self.NextWaypointIndex = 2

		-- Always create a fresh connection so it closes over the current `waypoints`
		self.ReachedConnection = humanoid.MoveToFinished:Connect(function(reached)
			if not self.CurrentlyMoving then
				return
			end
			if reached and self.NextWaypointIndex < #waypoints then
				self.NextWaypointIndex += 1

				humanoid:MoveTo(waypoints[self.NextWaypointIndex].Position)
			else
				self.CurrentlyMoving = false
				if self.ReachedConnection then
					self.ReachedConnection:Disconnect()
					self.ReachedConnection = nil
				end
				if self.BlockedConnection then
					self.BlockedConnection:Disconnect()
					self.BlockedConnection = nil
				end
				AISignals.PathfindComplete:Fire()
			end
		end)

		-- Move to the first meaningful waypoint
		humanoid:MoveTo(waypoints[self.NextWaypointIndex].Position)
	end
end

return AI
