local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local ANIMS = {
	idle = { normal = "idle", legless = "crawlidle" },
	walk = { normal = "walk", legless = "crawlwalk" },
	run = { normal = "run", legless = "crawlwalk" },
}
local FLAT = Vector3.new(1, 0, 1)
local CANDIDATE_TAGS = { "NPC", "Player", "Animal" }
local ARRIVE_DISTANCE = 2
local function hasAnyTag(model: Instance, tags): boolean
	for _, tag in tags do
		if model:HasTag(tag) then
			return true
		end
	end
	return false
end

local CommonStateLogic = {
	PlayLocomotion = function(agent, kind: "idle" | "walk" | "run")
		local set = ANIMS[kind]
		agent:PlayAnimation(if agent.legless then set.legless else set.normal, false, 1, 1)
	end,

	TryPathfind = function(agent, destination)
		if agent.busy or not destination then
			return false
		end

		local ai = agent.ai
		local requestId = (ai.pathRequestId or 0) + 1
		ai.pathRequestId = requestId

		agent.busy = true
		local ok, result = pcall(ai.pathfinder.findPath, ai.pathfinder, agent.position, destination)
		agent.busy = false

		-- state was exited while we yielded: discard the result
		if ai.pathRequestId ~= requestId then
			return false
		end

		if ok and result.success then
			ai.currentNavigationData = result
			ai.currentMoveIdx = 2
			return true
		end

		if not ok then
			Utility.Warn(`[TryPathfind] findPath errored: {result}`)
		end
		ai.currentNavigationData = nil
		agent:Move(Vector3.zero)
		return false
	end,

	-- MoveToward = function(agent: LightweightNpcTypes.npcRecordType, targetPos)
	-- 	local flatTarget = Vector3.new(targetPos.X, agent.position.Y, targetPos.Z)
	-- 	local dir = flatTarget - agent.position
	-- 	agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	-- end,
	MoveTowardFlattened = function(agent: LightweightNpcTypes.npcRecordType, targetPos)
		local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
		local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
		local dir = flatTarget - flatAgentPos
		agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	end,

	SetCurrentTarget = function(agent: LightweightNpcTypes.npcRecordType, target: Instance?)
		agent.serverRig:SetAttribute("CurrentTarget", target)
	end,
	GetCurrentTarget = function(agent: LightweightNpcTypes.npcRecordType)
		local exists = agent.serverRig:GetAttribute("CurrentTarget")
		return exists and exists:Get()
	end,

	CanSeeEnemy = function(npcRecord, dt)
		local enemyTags = npcRecord.enemies and npcRecord.enemies.EnemyList
		local perception = npcRecord.ai.perception
		local perceiverPos = npcRecord.position
		local npcTypeData = NPCTypes[npcRecord.npcType]
		local range = npcTypeData and npcTypeData.EyeRange

		if not perception or not enemyTags or not perceiverPos or not range then
			return nil
		end

		local rangeSq = range * range
		local hrp = npcRecord.hrp
		local hrpPos, look = hrp.Position, hrp.CFrame.LookVector

		for _, candidateTag in CANDIDATE_TAGS do
			for _, model: Model in Utility.GetTagInstancesInWorkspace(candidateTag) do
				if model == npcRecord.serverRig or model:HasTag("Dead") then
					continue
				end

				local modelPos = model:GetPivot().Position
				local offset = modelPos - perceiverPos
				if offset:Dot(offset) > rangeSq or not hasAnyTag(model, enemyTags) then
					continue
				end

				local targetId = model:GetAttribute("npcId") or model.Name
				if
					perception:processVisualDetection(targetId, hrpPos, look, modelPos)
					and perception:getAwarenessState(targetId) == "combat"
				then
					return model
				end
			end
		end

		return nil
	end,
}

--- Advances along ai.currentNavigationData. run = sprint speed + run animation.
function CommonStateLogic.FollowPath(agent, run: boolean): "moving" | "arrived" | "failed"
	local ai = agent.ai
	local waypoints = ai.currentNavigationData and ai.currentNavigationData.waypoints
	if not waypoints then
		return "failed"
	end

	local wp = waypoints[ai.currentMoveIdx]

	-- Jump first, so a close Jump waypoint can't be skipped by the arrival check
	if wp and wp.Action == Enum.PathWaypointAction.Jump and agent.isOnGround then
		agent:Jump()
		ai.currentMoveIdx += 1
		return "moving"
	end

	if wp and ((wp.Position - agent.position) * FLAT).Magnitude <= ARRIVE_DISTANCE then
		ai.currentMoveIdx += 1
		wp = waypoints[ai.currentMoveIdx]
	end
	if not wp then
		return "arrived"
	end

	if run then
		agent.configuration.walkSpeed = if agent.legless then HumanConstants.WALKSPEED else HumanConstants.SPRINT_SPEED
	end
	CommonStateLogic.MoveTowardFlattened(agent, wp.Position)
	if wp.Action ~= Enum.PathWaypointAction.Jump then
		CommonStateLogic.PlayLocomotion(agent, if run then "run" else "walk")
	end
	return "moving"
end
return CommonStateLogic
