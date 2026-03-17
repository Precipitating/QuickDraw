local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
type Human = ClassTypes.Human
type AIState = ClassTypes.AIState
local AI = {}
AI.__index = AI

function AI.new(owner: Human)
	local self = setmetatable({}, AI)
	assert(owner, "Owner incorrect for AI class initialization")
	self.Type = nil
	self.TypeInfo = nil
	self.CurrentState = "Idle" :: AIState
	self.Owner = owner
	self.NextWaypointIndex = nil
	self.ReachedConnection = nil
	self.BlockedConnection = nil
	self.CurrentlyMoving = false
	self.PathfindTolerance = 2
	self.NoiseSeed = RandomModule.GetRandom() * 1000
	return self
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
	local attackDist = self.TypeInfo.AttackDistance
	local dir = (targetPos - character:GetPivot().Position).Unit
	local distOffset = targetPos - (dir * attackDist)

	local success, errorMessage = pcall(function()
		path:ComputeAsync(character:GetPivot().Position, distOffset)
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
