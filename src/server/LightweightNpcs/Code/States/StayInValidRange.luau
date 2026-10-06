local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local LOOK_TIME = 1.5 -- max seconds spent turning/scanning after arriving (ends early once the target is found)
local BAND_TARGET = 0.5 -- 0 = aim for MinAttackDistance, 1 = aim for MaxAttackDistance
local MAX_REPOSITIONS = 3 -- arrivals that still end up out of band before giving up
local SEEK_IF_NOT_SPOTTED = true -- if the look window finds nobody, set lostTarget so Seek takes over
local BAND_MARGIN = 0.15 -- finish only inside the inner band (15% of its width in from each edge) so Attack's exit edges don't instantly re-trigger
local BAND_ANGLES = { 0, 30, -30, 60, -60 } -- degrees off the target->NPC line when picking a spot
local FLAT = Vector3.new(1, 0, 1)

local StayInValidRange = {}

-- Cleanup that must run whenever this state stops, however it stops.
function StayInValidRange:ExitStayInValidRangeState(agent: LightweightNpcTypes.npcRecordType)
	local ai = agent.ai
	ai.pathRequestId = (ai.pathRequestId or 0) + 1 -- discard any in-flight path
	ai.currentNavigationData = nil
	ai.currentMoveIdx = 2
	ai.lookUntil = nil
	ai.lookDone = nil

	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.configuration.walkSpeed = HumanConstants.WALKSPEED
	agent.busy = false
	CommonStateLogic.PlayLocomotion(agent, "idle")
end

local function finish(agent, result)
	StayInValidRange:ExitStayInValidRangeState(agent)
	agent.ai.repositionCount = nil
	return result
end

-- Stop moving, count this reposition, and stand/face the target for up to LOOK_TIME.
local function startLook(agent)
	local ai = agent.ai
	local count = (ai.repositionCount or 0) + 1
	StayInValidRange:ExitStayInValidRangeState(agent)
	ai.repositionCount = count
	ai.lookUntil = os.clock() + LOOK_TIME
end

-- Same "still engaged" test Attack uses: visible right now, or already at combat awareness.
-- Falls back to scanning for any enemy.
local function reacquireTarget(agent, target: Model, dt: number)
	local perception = agent.ai.perception
	local hrp = agent.hrp
	local targetId = target:GetAttribute("npcId") or target.Name

	local detected =
		perception:processVisualDetection(targetId, hrp.Position, hrp.CFrame.LookVector, target:GetPivot().Position)
	if detected or perception:getAwarenessState(targetId) == "combat" then
		return target
	end
	return CommonStateLogic.CanSeeEnemy(agent, dt)
end

-- Picks a reachable spot inside the band: straight along the target->NPC line first (a too-close NPC
-- backs straight off, a too-far one walks straight in), then fanned out to either side.
-- Also used by Hunt.
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

	local minDist, maxDist = factionData.MinAttackDistance, factionData.MaxAttackDistance
	local radius = minDist + (maxDist - minDist) * BAND_TARGET

	local targetPos = target:GetPivot().Position
	local away = (agent.position - targetPos) * FLAT
	away = if away.Magnitude > 0.001 then away.Unit else Vector3.zAxis

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { agent.serverRig, target }

	agent.busy = true
	local found
	-- Pass 1 only tries spots with a clear line of sight to the target (so the look can actually see it);
	-- pass 2 falls back to the blocked ones rather than failing outright.
	for pass = 1, 2 do
		for _, degrees in BAND_ANGLES do
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(degrees)):VectorToWorldSpace(away)
			local spot = targetPos + dir * radius
			local hit = workspace:Raycast(spot + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rayParams)
			local dest = if hit then hit.Position + Vector3.new(0, 1, 0) else spot

			local eye = dest + Vector3.new(0, 2.5, 0)
			local blocked = workspace:Raycast(eye, targetPos - eye, rayParams) ~= nil

			if blocked == (pass == 2) then
				local ok, nav = pcall(ai.pathfinder.findPath, ai.pathfinder, agent.position, dest)

				if ai.pathRequestId ~= requestId then
					return false -- state exited while we yielded; Exit already reset busy
				end
				if not ok then
					Utility.Warn(`[StayInValidRange] findPath errored: {nav}`)
				elseif nav.success then
					found = nav
					break
				end
			end
		end
		if found then
			break
		end
	end
	agent.busy = false

	if not found then
		Utility.Warn(`[StayInValidRange] no reachable spot inside the band`)
		return false
	end

	ai.currentNavigationData = found
	ai.currentMoveIdx = 2
	return true
end

function StayInValidRange:Update(agent: LightweightNpcTypes.npcRecordType, context)
	-- Getting hit: bail so Provoked can take over
	if agent.data.forceExitState then
		return finish(agent, ActionResult.Success)
	end
	if agent.busy then
		return ActionResult.Running
	end

	local ai = agent.ai
	local target = ai.lastSeenTarget
	local factionData = ai.factionData
	if not target or not target.Parent or target:HasTag("Dead") or not factionData then
		return finish(agent, ActionResult.Success)
	end

	-- 3D distance from the HRP, exactly what Attack measures, so the two states can't disagree
	local toTarget = target:GetPivot().Position - agent.hrp.Position
	local dist = toTarget.Magnitude
	local flatOffset = toTarget * FLAT

	-- Look window: turn to face the target and re-acquire it. Checked every tick, so the NPC
	-- re-engages as soon as it can see you instead of relying on one check at the end.
	if ai.lookUntil then
		if flatOffset.Magnitude > 0.001 then
			agent.targetAngle = MathUtils:PlayerVecToAngle(flatOffset)
		end

		local engaged = reacquireTarget(agent, target, context.dt)
		if engaged then
			CommonStateLogic.SetCurrentTarget(agent, engaged)
			ai.worldState:set("hasTarget", true)
			ai.worldState:set("lostTarget", false) -- a failed earlier look must not leave this stale
			ai.lastSeenPosition = engaged:GetPivot().Position
			ai.lookUntil = nil
			ai.lookDone = true
		elseif os.clock() >= ai.lookUntil then
			ai.lookUntil = nil
			ai.lookDone = true
			if SEEK_IF_NOT_SPOTTED then
				ai.worldState:set("lostTarget", true)
			end
		end
		return ActionResult.Running -- next tick re-evaluates the band
	end

	-- 1. Inside the valid band. Never leave without a look first, which also covers
	--    "already in band on the first tick" (no route), the usual cause of falling back to Patrol.
	local margin = (factionData.MaxAttackDistance - factionData.MinAttackDistance) * BAND_MARGIN
	if dist < factionData.MaxAttackDistance - margin and dist > factionData.MinAttackDistance + margin then
		if not ai.lookDone then
			startLook(agent)
			return ActionResult.Running
		end
		return finish(agent, ActionResult.Success)
	end

	-- 2. Give up if repositioning keeps ending out of band
	if (ai.repositionCount or 0) >= MAX_REPOSITIONS then
		return finish(agent, ActionResult.Failed)
	end

	-- 3. Need a route (a new route means a new look on arrival)
	if not self:GeneratePathWithinRange(agent) then
		return finish(agent, ActionResult.Failed)
	end
	ai.lookDone = nil

	-- 4. Follow it; on arrival, stop and look
	local status = CommonStateLogic.FollowPath(agent, true)
	if status == "failed" then
		return finish(agent, ActionResult.Failed)
	elseif status == "arrived" then
		startLook(agent)
	end

	return ActionResult.Running
end

return StayInValidRange
