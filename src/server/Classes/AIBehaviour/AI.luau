local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PatrolData = require(script.Parent.PatrolData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

type Human = ClassTypes.Human
type AIState = ClassTypes.AIState
local AI = {}
AI.__index = AI

AI.StatesLogic = {
	Idle = {
		Update = function(_) end,
	},
	Patrol = {
		Update = function(self, patrolData)
			self.Owner:ToggleRightArmAimer(false)
			self:Patrol(patrolData)
		end,
	},
	Seek = {
		Update = function(self)
			self.Owner:ToggleRightArmAimer(false)

			self:Seek()
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
	self.FinishedPathFind = nil
	self.LineOfSight = 0
	self.PathfindTolerance = 2
	self.MinAttackDistance = 0

	return self
end

function AI:IsTargetInView(originPos: Vector3, target: BasePart | Model | Vector3)
	-- Resolve target position
	local targetPos: Vector3
	if typeof(target) == "Vector3" then
		targetPos = target
	elseif typeof(target) == "Instance" then
		if target:IsA("Model") then
			targetPos = target:GetPivot().Position
		elseif target:IsA("BasePart") then
			targetPos = target.Position
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

	-- Target is beyond line of sight range
	if distance > self.LineOfSight then
		return false
	end

	-- Early out if distance is essentially zero
	if distance < 0.01 then
		return true
	end

	local dirUnit = direction.Unit

	-- ── FOV Check ──────────────────────────────────────────────
	local fov = 120
	local lookDir = self.Owner.HRP.CFrame.LookVector
	if self.LookDirection then
		local halfFOV = math.rad(fov / 2)
		local dot = lookDir:Dot(dirUnit)
		-- Clamp to avoid floating‑point issues with math.acos
		local angle = math.acos(math.clamp(dot, -1, 1))

		if angle > halfFOV then
			return false -- target is outside the field of view cone
		end
	end

	-- ── Raycast (line‑of‑sight occlusion check) ───────────────
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { self.Owner.Character }

	local result = workspace:Raycast(originPos, dirUnit * distance, raycastParams)

	-- Nothing was hit → clear line of sight to a Vector3 point
	if not result then
		-- If the target was just a position, nothing blocking means visible
		if typeof(target) == "Vector3" then
			return true
		end
		-- Ray traveled the full distance without hitting anything;
		-- this can happen if the target has CanQuery = false, etc.
		return false
	end

	-- ── Ancestor check ─────────────────────────────────────────
	-- Walk up from the hit instance to see if it belongs to the target.
	-- This handles models with nested parts (accessories, tools, etc.)
	if typeof(target) == "Instance" then
		local hit = result.Instance
		while hit do
			if hit == target then
				return true
			end
			hit = hit.Parent
		end
	end

	return false
end
function AI:ChangeState(newState: string, ...)
	if newState == self.CurrentState then
		return
	end

	local stateUpdate = self.StatesLogic[newState]
	if not stateUpdate and not stateUpdate[newState] then
		error("[ChangeState] Missing state logic")
	end
	self.CurrentState = newState
	warn(`New state = {self.CurrentState}`)
	stateUpdate.Update(self, ...)
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

	for _ = 1, 4 do
		if self.CurrentState ~= "Seek" then
			return false
		end
		local hrp = self.Owner.HRP
		local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
		torsoAimer.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLook) * CFrame.Angles(0, math.rad(90), 0)
		local foundEnemy = self:CheckSurroundingsForEnemy()
		if foundEnemy then
			torsoAimer.Enabled = false
			return true
		end
		task.wait(1)
	end
	torsoAimer.Enabled = false

	return false
end

function AI:Seek()
	if not self.LastSeenTargetPosition then
		AI.ChangeState(self, "Patrol", PatrolData["Test"])
		return
	end

	-- move to last seen position
	self:PathFindTo(self.LastSeenTargetPosition)

	while not self.FinishedPathFind do
		task.wait()
	end
	self.CurrentlyMoving = false
	self.LastSeenTargetPosition = nil

	-- have a look around 4 directions for any enemies
	local foundEnemy = self:LookAround()

	if foundEnemy then
		return
	end

	if not self.Owner then
		return
	end
	AI.ChangeState(self, "Patrol", PatrolData["Test"])
end

function AI:CheckSurroundingsForEnemy()
	-- check surroundings for enemy

	if self.CurrentState ~= "Patrol" then
		return false
	end
	local foundParts = self:CheckLineOfSight()
	if not foundParts then
		return false
	end

	for _, part in foundParts do
		if part:IsA("MeshPart") then
			local parent = part.Parent
			local isHuman = parent and part.Parent:FindFirstChild("Humanoid")
			if isHuman and CollectionService:HasTag(parent, "Player") then
				local visible = AI.IsTargetInView(self, self.Owner.BodyParts["Head"].Position, parent.HumanoidRootPart)
				if visible then
					AI.ChangeState(self, "Attack", parent)
					return true
				end
			end
		end
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
	task.spawn(function()
		while task.wait(0.1) do
			self:CheckSurroundingsForEnemy()
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

	local foundParts = workspace:GetPartBoundsInRadius(hrp, self.LineOfSight)
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

	self.FinishedPathFind = false
	local success, errorMessage = pcall(function()
		path:ComputeAsync(character:GetPivot().Position, targetPos)
	end)

	if not success then
		warn(`AI failed to pathfind: {errorMessage}`)
		return
	end

	if path.Status == Enum.PathStatus.Success then
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
				self:PathFindTo(targetPos)
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
				self.FinishedPathFind = true
			end
		end)

		-- Move to the first meaningful waypoint
		humanoid:MoveTo(waypoints[self.NextWaypointIndex].Position)
	end
end

return AI
