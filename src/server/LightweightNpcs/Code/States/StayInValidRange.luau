local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local StayInValidRange = {}

function StayInValidRange:ExitStayInValidRangeState(agent: LightweightNpcTypes.npcRecordType) end

function StayInValidRange:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local target = agent.ai.lastSeenTarget
	local rightHand = agent.bodyParts[LimbsEnum.RightHand]
	local npcData = agent.ai.factionData
	local perception = agent.ai.perception
	if not target or not rightHand or not npcData then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Failed
	end
	local targetPos = target:GetPivot().Position
	targetPos = Vector3.new(targetPos.X, 0, targetPos.Z)
	local currentPos = Vector3.new(agent.hrp.Position.X, 0, agent.hrp.Position.Z)
	local currentDist = (targetPos - currentPos).Magnitude
	local maxAttackDist = npcData.MaxAttackDistance
	local minAttackDist = npcData.MinAttackDistance
	local radius = RandomModule.GetRandomIntBetween(minAttackDist, maxAttackDist)
	local destination = nil

	-- 1. If within range return early
	if currentDist < maxAttackDist and currentDist > minAttackDist then
		return ActionResult.Success
	end

	-- 2. Move to waypoint within attack range
	destination = CommonStateLogic.FindAnglePosition(agent, rightHand.Position, targetPos, radius, 3)
	if not destination then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Success
	end

	local pathToDest = CommonStateLogic.TryPathfind(agent, destination)
	if not pathToDest then
		self:ExitStayInValidRangeState(agent)
		return ActionResult.Failed
	end
	agent.ai.currentNavigationData = pathToDest
	agent.ai.currentMoveIdx = 2

	local wp = pathToDest.waypoint
	local nextWaypoint = wp[agent.ai.currentMoveIdx]
	local flattenedNextWaypoint = Vector3.new(nextWaypoint.Position.X, 0, nextWaypoint.Position.Z)

	if (currentPos - flattenedNextWaypoint).Magnitude <= 2 then
		agent.ai.currentMoveIdx += 1
		nextWaypoint = wp[agent.ai.currentMoveIdx]

		if not nextWaypoint then
			return ActionResult.Success
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

return StayInValidRange
