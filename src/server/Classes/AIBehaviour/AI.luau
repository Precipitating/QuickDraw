local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AISignals = require(script.Parent.AISignals)
local PatrolData = require(script.Parent.PatrolData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)

type Human = ClassTypes.Human
type AIState = ClassTypes.AIState
local AI = {}
AI.__index = AI

AI.StatesLogic = {
	Idle = {
		Enter = function(self)
			self:StateChangeReset()
		end,
		Update = function(_) end,
		Exit = function(self)
			self:StateChangeReset()
		end,
	},
	Patrol = {
		Enter = function(self, patrolData)
			self:StateChangeReset()
			self.CurrentState = "Patrol"
			self.StatesLogic["Patrol"].Update(self, patrolData)
		end,
		Update = function(self, patrolData)
			self:Patrol(patrolData)
		end,
		Exit = function(self) end,
	},
	Seek = {
		Enter = function(self)
			self:StateChangeReset()
			self.CurrentState = "Seek"
			if not self.Owner.Legless then
				self.Owner.Humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
			end
			self.StatesLogic["Seek"].Update(self)
		end,
		Update = function(self)
			self:Seek()
		end,
		Exit = function(self)
			self.Owner.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
		end,
	},

	Dead = {
		Enter = function(self)
			self:StateChangeReset()
		end,
	},
}

function AI.new(owner: Human)
	local self = setmetatable({}, AI)
	assert(owner, "Owner incorrect for AI class initialization")
	self.Type = nil
	self.TypeInfo = nil
	self.CurrentState = "Idle" :: AIState
	self.Owner = owner
	self.CurrentlyMoving = false
	self.PatrolPoints = nil
	self.Reloading = false
	self.LastSeenTargetPosition = nil
	self.NextWaypointIndex = nil
	self.ReachedConnection = nil
	self.Target = nil
	self.BlockedConnection = nil

	self.PathfindTolerance = 2
	self.MinAttackDistance = 0
	self.MaxAttackDistance = 0

	self:EnableEnemyDetection()

	return self
end

function AI:StateChangeReset()
	self:CancelPathFind()
	self.CurrentlyMoving = false
	self.Owner:ToggleRightArmAimer(false)

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
	print("Cancel pathfind")
end

function AI:EnableEnemyDetection()
	task.spawn(function()
		while task.wait(0.1) do
			if self.CurrentState == "Attack" then
				continue
			end
			if self.CurrentState == "Idle" or self.CurrentState == "Dead" or self.Owner.Dead then
				return
			end
			self:CheckSurroundingsForEnemy()
		end
	end)
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
function AI:ChangeState(newState: string, ...)
	if newState == self.CurrentState then
		return
	end

	-- run current exit state
	local stateExit = self.StatesLogic[self.CurrentState]
	if stateExit then
		stateExit.Exit(self, ...)
	else
		error(`[ChangeState] Missing exit function for {stateExit}`)
	end

	local stateEnter = self.StatesLogic[newState]
	if stateEnter then
		stateEnter.Enter(self, ...)
	else
		error(`[ChangeState] Missing enter function for {stateEnter}`)
	end

	warn(`New state = {newState}`)
end

-- look in 4 directions and attempt to find an enemy, prompting 'Attack' state if so.
function AI:LookAround()
	local torsoAimer = self.Owner.TorsoAimer
	torsoAimer.Enabled = true
	self.CurrentlyMoving = false
	if not torsoAimer then
		warn("[LookAround] Missing torso aimer!")
		return
	end

	for _ = 1, 8 do
		if self.CurrentState ~= "Seek" then
			return false
		end
		local hrp = self.Owner.HRP
		local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
		torsoAimer.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook) * CFrame.Angles(0, math.rad(45), 0)

		task.wait(1)
	end
	torsoAimer.Enabled = false

	return false
end

function AI:Seek()
	if not self.LastSeenTargetPosition or not self.Owner then
		if self.CurrentState == "Seek" then
			AI.ChangeState(self, "Patrol", PatrolData["Test"])
		end
		return
	end

	-- move to last seen position
	self:PathFindTo(self.LastSeenTargetPosition)

	AISignals.PathfindComplete:Wait()

	self.LastSeenTargetPosition = nil

	-- have a look around 4 directions for any enemies
	local foundEnemy = self:LookAround()

	if foundEnemy then
		return
	end

	if self.CurrentState == "Seek" then
		AI.ChangeState(self, "Patrol", PatrolData["Test"])
	end
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

		if not hrp or not humanoid or not CollectionService:HasTag(parent, "NPC") then
			continue
		end

		local head = self.Owner and self.Owner.BodyParts and self.Owner.BodyParts["Head"]
		if not head then
			continue
		end

		local visible = AI.IsTargetInView(self, head.Position, hrp, true)
		if not visible then
			continue
		end

		AI.ChangeState(self, "Attack", parent)
		return true
	end

	return false
end

function AI:Patrol(patrolData)
	task.spawn(function()
		while task.wait(RandomModule.GetRandomIntBetween(1, 5)) do
			if self.CurrentState ~= "Patrol" then
				return
			end
			if self.CurrentlyMoving then
				continue
			end
			self:PathFindTo(patrolData[RandomModule.GetRandomIntBetween(1, #patrolData)])
		end
	end)
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
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 6,
		AgentCanJump = true,
		AgentCanClimb = true,
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

	if path.Status == Enum.PathStatus.Success then
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
