local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local PatrolData = ServerStorage.PatrolData
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local Patrol = {}
local function MoveToward(agent, targetPos)
	local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
	local dir = flatTarget - flatAgentPos
	agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
end

function Patrol:ExitPatrolState(agent)
	agent:Move(Vector3.zero)
	agent.ai.currentNavigationData = nil
	agent.ai.currentMoveIdx = nil
	agent.ai.worldState:set("patrolling", false)
end

function Patrol:GetNextPatrolPoint(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord then
		Utility.Warn(`[GetNextPatrolPoint] Missing npcRecord`)
		return nil
	end
	local patrolPoints = npcRecord.defaultStateData
	if not patrolPoints then
		Utility.Warn(`[GetNextPatrolPoint] Missing default state data`)
		return nil
	end
	local patrolData = PatrolData[patrolPoints]
	patrolData = patrolData:GetChildren()

	if #patrolData <= 0 then
		Utility.Warn(`[GetNextPatrolPoint] Patrol points folder {patrolPoints} missing points`)
		return nil
	end

	local randomPoint = patrolData[RandomModule.GetRandomIntBetween(1, #patrolData)]

	if not randomPoint then
		Utility.Warn(`[GetNextPatrolPoint] Cannot get a random point inside PatrolData {patrolPoints}`)
		return nil
	end

	return randomPoint.Position
end
function Patrol:TryPathfind(agent, destination)
	local calcPath = agent.ai.pathfinder:findPath(agent.position, destination)

	if calcPath.success then
		agent.ai.currentNavigationData = calcPath
		agent.ai.currentMoveIdx = 2
		return true
	end

	agent.ai.currentNavigationData = nil
	agent:Move(Vector3.zero)
	return false
end

local function CanSeeEnemy(npcRecord: LightweightNpcTypes.npcRecordType)
	local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
	local perception = npcRecord.ai.perception
	local perceiverPos = npcRecord.position
	local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
	if not perception or not enemyInstanceTags or not perceiverPos or not range then
		return nil
	end

	local target = nil

	local nearbyObjects = workspace:GetPartBoundsInRadius(npcRecord.position, range)

	for _, part in nearbyObjects do
		if not part:IsA("BasePart") then
			continue
		end
		for _, tag in enemyInstanceTags do
			if CollectionService:HasTag(part, tag) and part.Parent then
				if
					perception:canSee(
						npcRecord.position,
						npcRecord.hrp.CFrame.LookVector,
						part.Parent:GetPivot().Position,
						true
					)
				then
					target = part.Parent
					return target
				end
			end
		end
	end

	return nil
end

function Patrol:Update(agent)
	local seesTarget = CanSeeEnemy(agent)
	if seesTarget then
		agent.ai.worldState:set("hasTarget", seesTarget)
		agent:Move(Vector3.zero)

		return false
	end

	-- 1. Set patrol route if none set.
	if not agent.ai.currentNavigationData and not agent.busy then
		agent.busy = true
		local success = self:TryPathfind(agent, self:GetNextPatrolPoint(agent))
		agent.busy = false
		return success
	end

	--

	-- 2. If waypoints not set, the path cannot be navigated
	local waypoints = agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints
	if not waypoints then
		agent:Move(Vector3.zero)
		agent.ai.worldState:set("patrolling", false)
		return false
	end

	local nextWaypoint = waypoints[agent.ai.currentMoveIdx]
	if not nextWaypoint then
		return false
	end
	--

	local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local flatTarget = Vector3.new(nextWaypoint.Position.X, 0, nextWaypoint.Position.Z)

	-- 3. If reached the waypoint within a 2 stud distance, go next waypoint
	if (flatTarget - flatAgentPos).Magnitude <= 2 then
		agent.ai.currentMoveIdx += 1
		nextWaypoint = waypoints[agent.ai.currentMoveIdx]

		-- 3.1. If no waypoints left, we've reached our destination. Set a new one
		if not nextWaypoint then
			self:TryPathfind(agent, self:GetNextPatrolPoint(agent))
			return true
		end
	end

	-- 4. Still traversing the current waypoint
	if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
		if agent.isOnGround then
			agent:Jump()
			agent.ai.currentMoveIdx += 1
		else
			-- still walking toward the jump point while airborne/not-yet-grounded;
			-- don't leave motionVector frozen
			MoveToward(agent, nextWaypoint.Position)
		end
	else
		MoveToward(agent, nextWaypoint.Position)
		agent:PlayAnimation("walk", false, 1, 1)
	end

	return true
end
return Patrol
