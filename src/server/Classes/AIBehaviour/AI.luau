local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

type Human = ClassTypes.Human
type AIState = ClassTypes.AIState
local AI = {}
AI.__index = AI

AI.StatesLogic = {
	Idle = { Update = function(self) end },
	Patrol = {
		Update = function(self, patrolData)
			if self.RightArmAimer then
				self.RightArmAimer.Enabled = false
			end
			self:Patrol(patrolData)
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
	self.NextWaypointIndex = nil
	self.ReachedConnection = nil
	self.Target = nil
	self.BlockedConnection = nil
	self.LineOfSight = 0
	self.PathfindTolerance = 2
	self.MinAttackDistance = 0

	self.NoiseSeed = RandomModule.GetRandom() * 1000
	return self
end

function AI:IsTargetInView(originPos: Vector3, target: BasePart | Model | Vector3)
	local targetPos = nil

	if typeof(target) == "Vector3" then
		targetPos = target
	elseif target:IsA("Model") then
		targetPos = target:GetPivot().Position
	elseif target:IsA("BasePart") then
		targetPos = target.Position
	end

	local dir = (targetPos - originPos).Unit
	local raycastParam = RaycastParams.new()
	raycastParam.FilterDescendantsInstances = { self.Owner.Character }
	local lineOfSight = workspace:Raycast(originPos, dir * self.LineOfSight, raycastParam)

	-- local part = Instance.new("Part")
	-- part.Parent = workspace
	-- part.CFrame = CFrame.lookAt(originPos, originPos + dir) * CFrame.new(0, 0, -self.LineOfSight / 2)
	-- part.Size = Vector3.new(0.2, 0.2, self.LineOfSight)
	-- part.CanCollide = false
	-- part.CanQuery = false
	-- part.Anchored = true

	--Debris:AddItem(part, 1)

	if lineOfSight and (lineOfSight.Instance == target or lineOfSight.Instance.Parent == target) then
		--part.Color = Color3.fromRGB(0, 255, 0)
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

	-- check surroundings for enemy
	task.spawn(function()
		while task.wait(1) do
			local foundParts = self:CheckLineOfSight()
			for _, part in foundParts do
				if part:IsA("MeshPart") then
					local parent = part.Parent
					local isHuman = parent and part.Parent:FindFirstChild("Humanoid")
					if isHuman and CollectionService:HasTag(parent, "Player") then
						local visible =
							AI.IsTargetInView(self, self.Owner.BodyParts["Head"].Position, parent.HumanoidRootPart)
						if visible then
							AI.ChangeState(self, "Attack", parent)
							return
						end
					end
				end
			end
		end
	end)
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

function AI:CheckLineOfSight()
	local LineOfSightParams = OverlapParams.new()
	LineOfSightParams.FilterType = Enum.RaycastFilterType.Exclude
	LineOfSightParams.FilterDescendantsInstances = { self.Owner.Character }
	local hrp = self.Owner.HRP.Position
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
			end
		end)

		-- Move to the first meaningful waypoint
		humanoid:MoveTo(waypoints[self.NextWaypointIndex].Position)
	end
end

return AI
