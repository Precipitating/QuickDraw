local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local PatrolData = ServerStorage.PatrolData
local ARRIVE_DISTANCE = 2
local FLAT = Vector3.new(1, 0, 1)

local patrolPointCache: { [string]: { Vector3 } } = {}

local function getPatrolPositions(folderName: string): { Vector3 }?
	local cached = patrolPointCache[folderName]
	if cached then
		return cached
	end

	local folder = PatrolData:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local positions = {}
	for _, point in folder:GetChildren() do
		if point:IsA("BasePart") then
			table.insert(positions, point.Position)
		end
	end
	if #positions == 0 then
		return nil
	end

	patrolPointCache[folderName] = positions
	return positions
end

local Patrol = {}

function Patrol:ExitPatrolState(agent: LightweightNpcTypes.npcRecordType)
	local ai = agent.ai
	ai.pathRequestId = (ai.pathRequestId or 0) + 1 -- invalidates any in-flight findPath
	ai.currentNavigationData = nil
	agent.busy = false
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	CommonStateLogic.PlayLocomotion(agent, "idle")
end

local function fail(agent)
	Patrol:ExitPatrolState(agent)
	return ActionResult.Failed
end

function Patrol:GetNextPatrolPoint(agent: LightweightNpcTypes.npcRecordType): Vector3?
	local folderName = agent.defaultStateData
	local positions = folderName and getPatrolPositions(folderName)
	if not positions then
		Utility.Warn(`[GetNextPatrolPoint] No usable patrol points for {folderName}`)
		return nil
	end
	return positions[RandomModule.GetRandomIntBetween(1, #positions)]
end

function Patrol:TryGetNextPatrolWaypoint(agent: LightweightNpcTypes.npcRecordType): boolean
	return CommonStateLogic.TryPathfind(agent, self:GetNextPatrolPoint(agent))
end

function Patrol:Update(agent, context)
	if agent.data.forceExitState then
		self:ExitPatrolState(agent)
		return ActionResult.Success
	end
	if agent.busy then
		return ActionResult.Running
	end

	local seen = CommonStateLogic.CanSeeEnemy(agent, context.dt)
	if seen then
		CommonStateLogic.SetCurrentTarget(agent, seen)
		self:ExitPatrolState(agent)
		ServerSoundHandler:Play3DNPCVoiceline(
			nil,
			`RangedAIAttack{RandomModule.GetRandomIntBetween(1, 3)}{agent.npcType}`,
			agent.npcSound,
			{ MaxDistance = 150 }
		)
		return ActionResult.Success
	end

	local ai = agent.ai

	-- 1. Need a route
	if not ai.currentNavigationData and not self:TryGetNextPatrolWaypoint(agent) then
		return fail(agent)
	end

	local waypoints = ai.currentNavigationData and ai.currentNavigationData.waypoints
	local wp = waypoints and waypoints[ai.currentMoveIdx]
	if not wp then
		return fail(agent)
	end

	-- 2. Jump first, so a close Jump waypoint can't be skipped by the arrival check
	local isJump = wp.Action == Enum.PathWaypointAction.Jump
	if isJump and agent.isOnGround then
		agent:Jump()
		ai.currentMoveIdx += 1
		return ActionResult.Running
	end

	-- 3. Arrival
	if ((wp.Position - agent.position) * FLAT).Magnitude <= ARRIVE_DISTANCE then
		ai.currentMoveIdx += 1
		wp = waypoints[ai.currentMoveIdx]
		if not wp then
			-- destination reached; next tick picks a new one (add an idle pause here if you want)
			ai.currentNavigationData = nil
			return ActionResult.Running
		end
	end

	-- 4. Move
	CommonStateLogic.MoveTowardFlattened(agent, wp.Position)
	if wp.Action ~= Enum.PathWaypointAction.Jump then
		CommonStateLogic.PlayLocomotion(agent, "walk")
	end
	return ActionResult.Running
end

return Patrol
