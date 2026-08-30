local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local Seek = {}

function Seek:ExitSeekState(agent: LightweightNpcTypes.npcRecordType)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.configuration.walkSpeed = HumanConstants.WALKSPEED
	agent.ai.currentNavigationData = nil
	agent.ai.currentMoveIdx = 2
	agent.busy = false

	if not agent.legless then
		agent:PlayAnimation("idle", false, 1, 1)
	else
		agent:PlayAnimation("crawlidle", false, 1, 1)
	end
end

function Seek:LookAroundForTarget(agent: LightweightNpcTypes.npcRecordType, dt: number)
	agent:PlayAnimation("idle", false, 1, 1)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.busy = true
	for _ = 1, 4 do
		warn("ROTATIN")
		if agent.ai.worldState:get("hasTarget") then
			agent.busy = false
			return
		end
		agent.targetAngle += math.rad(90)
		task.wait(1)
	end
	agent.busy = false
end
function Seek:GeneratePathToLastSeenTarget(agent, forceReset: boolean?)
	local currentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local lastSeenTarget = agent.ai.lastSeenTarget
	local perception = agent.ai.perception

	if forceReset or (not agent.ai.currentNavigationData and not agent.busy) then
		-- 2. Get the last seen target's position
		local lastSeenPos = perception:getLastKnownPosition(lastSeenTarget:GetAttribute("npcId") or lastSeenTarget.Name)

		---
		if not lastSeenPos then
			Utility.Warn(`[SEEK] No last seen position, exiting state`)
			return false
		end

		-- DEBUG LAST SEEN
		local p1 = Instance.new("Part", workspace)
		p1.Name = "lastSeen"
		p1.Anchored = true
		p1.Size = Vector3.new(0.5, 0.5, 0.5)
		p1.Position = lastSeenPos
		p1.CanCollide = false
		p1.Color = Color3.fromRGB(0, 47, 255)

		task.delay(5, function()
			p1:Destroy()
		end)

		local flankPath = agent.ai.pathfinder:findFlankingPath(currentPos, lastSeenPos)
		if not flankPath then
			Utility.Warn(`[SEEK] No flank path, exiting state`)
			return false
		end

		local setFlankPath = flankPath.success
		if not setFlankPath then
			Utility.Warn(`[SEEK] No calculated flank path, exiting state`)
			return false
		end
		agent.ai.currentMoveIdx = 2
		agent.ai.currentNavigationData = flankPath

		-- DEBUG
		for _, path in flankPath.waypoints do
			local p2 = Instance.new("Part", workspace)
			p2.Anchored = true
			p2.Size = Vector3.new(0.5, 0.5, 0.5)
			p2.Position = path.Position
			p2.CanCollide = false
			p2.Color = Color3.fromRGB(0, 255, 0)
			task.delay(5, function()
				p2:Destroy()
			end)
		end
	end
	return true
end
function Seek:Update(agent, context)
	Utility.Warn(`Seekin`)
	local lastSeenTarget = agent.ai.lastSeenTarget
	local currentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local dt = context.dt

	--
	if not lastSeenTarget then
		Utility.Warn(`[SEEK] No last seen target, exiting state`)
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	-- 1. Check if we see an enemy, and  go attack state if so
	local seesEnemy = CommonStateLogic.CanSeeEnemy(agent, dt)
	if seesEnemy then
		agent.ai.worldState:set("hasTarget", true)
		agent.ai.currentTarget = seesEnemy
		warn("AI sees enemy")
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	if agent.busy then
		return ActionResult.Running
	end

	--
	-- 2. Set the flank path waypoints if not set
	local generatedPath = self:GeneratePathToLastSeenTarget(agent, false)

	if not generatedPath then
		Utility.Warn(`[SEEK] Cannot generate path to last seen position, exiting state`)
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	-- 3. Run towards the last seen target's position via flank position (waypoint -> waypoint ... -> destination)
	local waypoints = agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints
	if not waypoints then
		Utility.Warn(`[SEEK] No waypoints, exiting state`)
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	-- 3.1  If reached waypoint already, rotate and exit if enemy not found
	if agent.ai.currentMoveIdx > #waypoints then
		Utility.Warn(`Reached flank position`)
		self:LookAroundForTarget(agent, dt)
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	-- 4. Current waypoint reached, go next waypoint
	local nextWaypoint = waypoints[agent.ai.currentMoveIdx]
	local flattenedNextWaypoint = Vector3.new(nextWaypoint.Position.X, 0, nextWaypoint.Position.Z)

	if (currentPos - flattenedNextWaypoint).Magnitude <= 2 then
		agent.ai.currentMoveIdx += 1
		nextWaypoint = waypoints[agent.ai.currentMoveIdx]

		if not nextWaypoint then
			return ActionResult.Running
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
			agent.configuration.walkSpeed = if not agent.legless
				then HumanConstants.SPRINT_SPEED
				else HumanConstants.WALKSPEED

			if not agent.legless then
				agent:PlayAnimation("run", false, 1, 1)
			else
				agent:PlayAnimation("crawlwalk", false, 1, 1)
			end
			CommonStateLogic.MoveToward(agent, nextWaypoint.Position)
		end
	end

	return ActionResult.Running
end

return Seek
