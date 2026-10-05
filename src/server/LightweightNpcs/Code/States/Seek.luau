local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local LOOK_STEPS = 4 -- quarter turns while scanning (4 = full circle)
local LOOK_STEP_TIME = 1 -- seconds per quarter turn
local LOOK_STEP_ANGLE = math.rad(90)

local Seek = {}

function Seek:ExitSeekState(agent: LightweightNpcTypes.npcRecordType)
	local ai = agent.ai
	ai.pathRequestId = (ai.pathRequestId or 0) + 1 -- discard any in-flight path
	ai.currentNavigationData = nil
	ai.currentMoveIdx = 2
	ai.lookStepsLeft = nil
	ai.nextLookStep = nil

	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.configuration.walkSpeed = HumanConstants.WALKSPEED
	agent.busy = false
	CommonStateLogic.PlayLocomotion(agent, "idle")
end

local function BeginScan(agent)
	Seek:ExitSeekState(agent) -- stop moving, reset speed, clear the path
	agent.ai.lookStepsLeft = LOOK_STEPS
	agent.ai.nextLookStep = 0
end

-- Also called by the bump-recovery handler in NPCLogic (forceReset = true).
function Seek:GeneratePathToLastSeenTarget(agent: LightweightNpcTypes.npcRecordType, forceReset: boolean?): boolean
	local ai = agent.ai
	if not forceReset and ai.currentNavigationData then
		return true
	end

	local target = ai.lastSeenTarget
	if not target then
		return false
	end

	local lastSeenPos = ai.perception:getLastKnownPosition(target:GetAttribute("npcId") or target.Name)
	if not lastSeenPos then
		Utility.Warn(`[SEEK] No last seen position`)
		return false
	end

	local requestId = (ai.pathRequestId or 0) + 1
	ai.pathRequestId = requestId

	agent.busy = true
	local ok, flankPath = pcall(ai.pathfinder.findFlankingPath, ai.pathfinder, agent.position, lastSeenPos)
	agent.busy = false

	if ai.pathRequestId ~= requestId then
		return false -- state exited while we yielded; discard
	end
	if not ok then
		Utility.Warn(`[SEEK] findFlankingPath errored: {flankPath}`)
		return false
	end
	if not flankPath or not flankPath.success then
		return false
	end

	ai.currentMoveIdx = 2
	ai.currentNavigationData = flankPath
	return true
end

function Seek:Update(agent: LightweightNpcTypes.npcRecordType, context)
	if agent.data.forceExitState then
		self:ExitSeekState(agent)
		return ActionResult.Success -- provoked takes over
	end

	local ai = agent.ai
	if not ai.lastSeenTarget then
		self:ExitSeekState(agent)
		return ActionResult.Success
	end

	-- 1. Spotted an enemy? Runs every tick, including while scanning
	local seen = CommonStateLogic.CanSeeEnemy(agent, context.dt)
	if seen then
		ai.worldState:set("hasTarget", true)
		CommonStateLogic.SetCurrentTarget(agent, seen)
		self:ExitSeekState(agent)
		ServerSoundHandler:Play3DNPCVoiceline(
			nil,
			`RangedAIAttack{RandomModule.GetRandomIntBetween(1, 3)}{agent.npcType}`,
			agent.npcSound,
			{ MaxDistance = 150 }
		)
		return ActionResult.Success
	end

	if agent.busy then
		return ActionResult.Running
	end

	-- 2. Scan phase: quarter turns on a timer, no yielding
	local stepsLeft = ai.lookStepsLeft
	if stepsLeft then
		local now = os.clock()
		if now >= ai.nextLookStep then
			if stepsLeft <= 0 then
				self:ExitSeekState(agent)
				return ActionResult.Success -- found nothing, give up (lostTarget = false)
			end
			agent.targetAngle += LOOK_STEP_ANGLE
			ai.lookStepsLeft = stepsLeft - 1
			ai.nextLookStep = now + LOOK_STEP_TIME
		end
		return ActionResult.Running
	end

	-- 3. Route to the last known position
	if not self:GeneratePathToLastSeenTarget(agent, false) then
		self:ExitSeekState(agent)
		return ActionResult.Success -- can't seek, give up
	end

	-- 4. Follow it, then scan on arrival
	local status = CommonStateLogic.FollowPath(agent, true)
	if status == "failed" then
		self:ExitSeekState(agent)
		return ActionResult.Success
	elseif status == "arrived" then
		BeginScan(agent)
	end

	return ActionResult.Running
end

return Seek
