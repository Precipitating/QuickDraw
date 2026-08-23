local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Seek = {}

function Seek:ExitSeekState(agent)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent:PlayAnimation("idle", false, 1, 1)
	agent.ai.worldState:set("seeking", false)
	agent.ai.worldState:set("lostTarget", false)
	agent.ai.currentPlan = nil
	agent.ai.lastSeenTarget = nil
	agent.ai.currentGoal = nil
	agent.configuration.walkSpeed = HumanConstants.WALKSPEED
	agent.ai.currentNavigationData = nil
	agent.ai.currentMoveIdx = 2
end

function Seek:Update(agent, context)
	Utility.Warn(`Seekin`)
	local lastSeenTarget = agent.ai.lastSeenTarget
	local dt = context.dt
	if not lastSeenTarget then
		self:ExitSeekState(agent)
		return false
	end

	-- 1. Check if we see an enemy, and should go attack state if so
	local perception = agent.ai.perception
	perception:update(dt)
	local seesEnemy = CommonStateLogic.CanSeeEnemy(agent, dt)
	if seesEnemy then
		agent.ai.worldState:set("hasTarget", true)
		agent.ai.currentTarget = seesEnemy
		warn("AI sees enemy")
		self:ExitSeekState(agent)
		return false
	end

	--
	--

	-- 2. Get the last seen target's position
	local lastSeenPos = perception:getLastKnownPosition(lastSeenTarget:GetAttribute("npcId") or lastSeenTarget.Name)
	local currentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	if not lastSeenPos then
		self:ExitSeekState(agent)
		return false
	end

	-- 3. Set the flank path waypoints if not set
	if not agent.ai.currentNavigationData and not agent.busy then
		local flankPath = agent.ai.pathfinder:findFlankingPath(currentPos, lastSeenPos)
		if not flankPath then
			self:ExitSeekState(agent)
			return false
		end

		local setFlankPath = flankPath.success
		if not setFlankPath then
			self:ExitSeekState(agent)
			return false
		end
		agent.ai.currentMoveIdx = 2
		agent.ai.currentNavigationData = flankPath
	end

	-- 4. Run towards the last seen target's position via flank position (waypoint by waypoint)
	local waypoints = agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints
	if not waypoints then
		self:ExitSeekState(agent)
		return false
	end

	local nextWaypoint = waypoints[agent.ai.currentMoveIdx]

	-- 5. Current waypoint reached, go next waypoint
	if (currentPos - nextWaypoint.Position).Magnitude <= 2 then
		agent.ai.currentMoveIdx += 1
		nextWaypoint = waypoints[agent.ai.currentMoveIdx]

		-- 5.1 Reached destination, have a look around and spot the target if so
		if not nextWaypoint then
			Utility.Warn(`Reached flank position`)
		end
	else
		-- 5.2 Move towards current waypoint target
		if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
			if agent.isOnGround then
				agent:Jump()
				agent.ai.currentMoveIdx += 1
			else
				CommonStateLogic.MoveToward(agent, nextWaypoint.Position)
			end
		else
			-- Run
			CommonStateLogic.MoveToward(agent, nextWaypoint.Position)
			agent.configuration.walkSpeed = HumanConstants.SPRINT_SPEED
			agent:PlayAnimation("run", false, 1, 1)
		end
	end

	return true
end

return Seek
