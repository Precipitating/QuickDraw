local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local StayInValidRange = {}

function StayInValidRange:ExitStayInValidRangeState(agent: LightweightNpcTypes.npcRecordType)
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

function StayInValidRange:GeneratePathWithinRange(agent: LightweightNpcTypes.npcRecordType)
	if agent.ai.currentNavigationData then
		return true
	end
	agent.busy = true

	local target = agent.ai.lastSeenTarget
	local npcData = agent.ai.factionData
	local maxAttackDist = npcData.MaxAttackDistance

	local targetPos = target:GetPivot().Position
	local flattenedTargetPos = Vector3.new(targetPos.X, 0, targetPos.Z)
	local currentPos = Vector3.new(agent.position.X, 0, agent.position.Z)

	-- 1. If not waypoints set, attempt to generate  one respecting radius
	local destination = agent.ai.pathfinder:findFlankingPath(currentPos, flattenedTargetPos, maxAttackDist * 0.3)
	if not destination then
		Utility.Warn(`Cannot get in-range angle position`)
		agent.busy = false
		return false
	end
	agent.ai.currentNavigationData = destination
	agent.ai.currentMoveIdx = 2
	agent.busy = false
	return true
end

local function CanStillSeeEnemy(agent: LightweightNpcTypes.npcRecordType, targetPos: Vector3, dt: number)
	local dir = (targetPos - Vector3.new(agent.position.X, 0, agent.position.Z)).Unit
	agent.targetAngle = MathUtils:PlayerVecToAngle(dir)

	agent.busy = true
	task.wait(1)

	-- 3. Check if we can see any enemies
	local seesTarget = CommonStateLogic.CanSeeEnemy(agent, dt)
	if seesTarget then
		agent.ai.currentTarget = seesTarget
		agent.ai.worldState:set("hasTarget", true)
		return true
	end

	return false
end

function StayInValidRange:Update(agent: LightweightNpcTypes.npcRecordType, context)
	if agent.busy then
		return ActionResult.Running
	end

	Utility.Warn(`StayInValidRange Entered`)
	local target = agent.ai.lastSeenTarget
	local npcData = agent.ai.factionData
	if not target or not npcData then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Success
	end
	local targetPos = target:GetPivot().Position
	targetPos = Vector3.new(targetPos.X, 0, targetPos.Z)
	local currentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local currentDist = (targetPos - currentPos).Magnitude

	-- -- 1. If within range return early
	if currentDist < npcData.MaxAttackDistance and currentDist > npcData.MinAttackDistance then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Success
	end

	-- 2. Set path to be in range if not set
	local success = self:GeneratePathWithinRange(agent)
	if not success then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Success
	end

	local wp = agent.ai and agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints

	if not wp then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Success
	end
	-- DEBUG
	for _, path in wp do
		local p2 = Instance.new("Part", workspace)
		p2.Anchored = true
		p2.Size = Vector3.new(0.5, 0.5, 0.5)
		p2.Position = path.Position
		p2.CanCollide = false
		p2.Color = Color3.fromRGB(0, 255, 0)
		task.delay(10, function()
			p2:Destroy()
		end)
	end

	--
	local nextWaypoint = wp[agent.ai.currentMoveIdx]
	local flattenedNextWaypoint = Vector3.new(nextWaypoint.Position.X, 0, nextWaypoint.Position.Z)

	-- Move towards waypoint
	if (flattenedNextWaypoint - currentPos).Magnitude <= 2 then
		agent.ai.currentMoveIdx += 1
		nextWaypoint = wp[agent.ai.currentMoveIdx]

		-- Finished pathfinding
		if not nextWaypoint then
			Utility.Warn(`PATHFIND FINISHED ON VALID RANGE`)
			self:ExitStayInValidRangeState(agent)
			CanStillSeeEnemy(agent, targetPos, context.dt)
			agent.busy = false
			return ActionResult.Success
		end
	else
		-- 5.2 Move towards current waypoint target
		if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
			if agent.isOnGround then
				agent:Jump()
				agent.ai.currentMoveIdx += 1
			else
				CommonStateLogic.MoveTowardFlattened(agent, nextWaypoint.Position)
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
			CommonStateLogic.MoveTowardFlattened(agent, nextWaypoint.Position)
		end
	end

	return ActionResult.Running
end

return StayInValidRange
