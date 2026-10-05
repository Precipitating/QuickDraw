local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local ARRIVE_DISTANCE = 2 -- studs from a waypoint (flat) to count as reached
local LOOK_TIME = 1 -- seconds spent standing and scanning after arriving
local BAND_TARGET = 0.5 -- 0 = aim for MinAttackDistance, 1 = aim for MaxAttackDistance
local MAX_REPOSITIONS = 3 -- arrivals that still end up out of band before giving up
local FLAT = Vector3.new(1, 0, 1)

local StayInValidRange = {}

-- Cleanup that must run whenever this state stops, however it stops.
function StayInValidRange:ExitStayInValidRangeState(agent: LightweightNpcTypes.npcRecordType)
	local ai = agent.ai
	ai.pathRequestId = (ai.pathRequestId or 0) + 1 -- discard any in-flight path
	ai.currentNavigationData = nil
	ai.currentMoveIdx = 2
	ai.lookUntil = nil

	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.configuration.walkSpeed = HumanConstants.WALKSPEED
	agent.busy = false
	CommonStateLogic.PlayLocomotion(agent, "idle")
end

local function Finish(agent, result)
	StayInValidRange:ExitStayInValidRangeState(agent)
	agent.ai.repositionCount = nil
	return result
end

function StayInValidRange:GeneratePathWithinRange(agent: LightweightNpcTypes.npcRecordType): boolean
	local ai = agent.ai
	if ai.currentNavigationData then
		return true
	end

	local target = ai.lastSeenTarget
	local factionData = ai.factionData
	if not target or not factionData then
		return false
	end

	local requestId = (ai.pathRequestId or 0) + 1
	ai.pathRequestId = requestId

	-- Aim for the inside of the valid band so arrival has margin on both sides.
	local minDist, maxDist = factionData.MinAttackDistance, factionData.MaxAttackDistance
	local radius = minDist + (maxDist - minDist) * BAND_TARGET

	agent.busy = true
	local ok, nav =
		pcall(ai.pathfinder.findFlankingPath, ai.pathfinder, agent.position, target:GetPivot().Position, radius)
	agent.busy = false

	if ai.pathRequestId ~= requestId then
		return false -- state exited while we yielded; discard
	end
	if not ok then
		Utility.Warn(`[StayInValidRange] findFlankingPath errored: {nav}`)
		return false
	end
	if not nav then
		return false -- no reachable position
	end

	ai.currentNavigationData = nav
	ai.currentMoveIdx = 2
	return true
end

function StayInValidRange:Update(agent: LightweightNpcTypes.npcRecordType, context)
	-- Getting hit: bail so Provoked can take over
	if agent.data.forceExitState then
		return Finish(agent, ActionResult.Success)
	end
	if agent.busy then
		return ActionResult.Running
	end

	local ai = agent.ai
	local target = ai.lastSeenTarget
	local factionData = ai.factionData
	if not target or not target.Parent or target:HasTag("Dead") or not factionData then
		return Finish(agent, ActionResult.Success)
	end

	local offset = (target:GetPivot().Position - agent.position) * FLAT
	local dist = offset.Magnitude

	-- Look window: arrived, stand still, face the target, then check once
	local lookUntil = ai.lookUntil
	if lookUntil then
		if dist > 0.001 then
			agent.targetAngle = MathUtils:PlayerVecToAngle(offset)
		end
		if os.clock() < lookUntil then
			return ActionResult.Running
		end
		ai.lookUntil = nil

		local seen = CommonStateLogic.CanSeeEnemy(agent, context.dt)
		if seen then
			CommonStateLogic.SetCurrentTarget(agent, seen)
			ai.worldState:set("hasTarget", true)
		end
		return ActionResult.Running -- next tick re-evaluates the band
	end

	-- 1. Inside the valid band: done
	if dist < factionData.MaxAttackDistance and dist > factionData.MinAttackDistance then
		return Finish(agent, ActionResult.Success)
	end

	-- 2. Give up if repositioning keeps ending out of band
	if (ai.repositionCount or 0) >= MAX_REPOSITIONS then
		return Finish(agent, ActionResult.Failed)
	end

	-- 3. Need a route
	if not self:GeneratePathWithinRange(agent) then
		return Finish(agent, ActionResult.Failed)
	end

	local waypoints = ai.currentNavigationData and ai.currentNavigationData.waypoints
	if not waypoints then
		return Finish(agent, ActionResult.Failed)
	end

	-- 4. Jump first, so a close Jump waypoint can't be skipped by the arrival check
	local wp = waypoints[ai.currentMoveIdx]
	if wp and wp.Action == Enum.PathWaypointAction.Jump and agent.isOnGround then
		agent:Jump()
		ai.currentMoveIdx += 1
		return ActionResult.Running
	end

	-- 5. Reached the current waypoint
	if wp and ((wp.Position - agent.position) * FLAT).Magnitude <= ARRIVE_DISTANCE then
		ai.currentMoveIdx += 1
		wp = waypoints[ai.currentMoveIdx]
	end

	-- 6. Out of waypoints: arrived. Stop, face the target, scan
	if not wp then
		local count = (ai.repositionCount or 0) + 1
		self:ExitStayInValidRangeState(agent)
		ai.repositionCount = count
		ai.lookUntil = os.clock() + LOOK_TIME
		return ActionResult.Running
	end

	-- 7. Run toward it
	agent.configuration.walkSpeed = if agent.legless then HumanConstants.WALKSPEED else HumanConstants.SPRINT_SPEED
	CommonStateLogic.MoveTowardFlattened(agent, wp.Position)
	if wp.Action ~= Enum.PathWaypointAction.Jump then
		CommonStateLogic.PlayLocomotion(agent, "run")
	end

	return ActionResult.Running
end

return StayInValidRange
