local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local PatrolData = ServerStorage.PatrolData
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Patrol = {}

function Patrol:ExitPatrolState(agent)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.busy = false

	if not agent.legless then
		agent:PlayAnimation("idle", false, 1, 1)
	else
		agent:PlayAnimation("crawlidle", false, 1, 1)
	end
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

function Patrol:TryGetNextPatrolWaypoint(npcRecord: LightweightNpcTypes.npcRecordType)
	local success = CommonStateLogic.TryPathfind(npcRecord, self:GetNextPatrolPoint(npcRecord))
	return success
end

function Patrol:Update(agent, context)
	if agent.data.forceExitState then
		Utility.Warn(`Force exit state on patrol!`)
		self:ExitPatrolState(agent)
		return ActionResult.Success
	end
	local dt = context.dt
	if agent.busy then
		return ActionResult.Running
	end

	local seesTarget = CommonStateLogic.CanSeeEnemy(agent, dt)
	if seesTarget then
		agent.ai.currentTarget = seesTarget
		warn("AI sees enemy")
		self:ExitPatrolState(agent)
		return ActionResult.Success
	end

	-- 1. Set patrol route if none set.
	if not agent.ai.currentNavigationData then
		local success = self:TryGetNextPatrolWaypoint(agent)

		if not success then
			self:ExitPatrolState(agent)
			return ActionResult.Failed
		end
	end

	--

	-- 2. If waypoints not set, the path cannot be navigated
	local waypoints = agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints
	if not waypoints then
		self:ExitPatrolState(agent)
		return ActionResult.Failed
	end

	local nextWaypoint = waypoints[agent.ai.currentMoveIdx]
	if not nextWaypoint then
		self:ExitPatrolState(agent)
		return ActionResult.Failed
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
			local success = self:TryGetNextPatrolWaypoint(agent)

			if not success then
				self:ExitPatrolState(agent)
				return ActionResult.Failed
			end
			return ActionResult.Running
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
			CommonStateLogic.MoveTowardFlattened(agent, nextWaypoint.Position)
		end
	else
		CommonStateLogic.MoveTowardFlattened(agent, nextWaypoint.Position)

		if not agent.legless then
			agent:PlayAnimation("walk", false, 1, 1)
		else
			agent:PlayAnimation("crawlwalk", false, 1, 1)
		end
	end

	return ActionResult.Running
end
return Patrol
