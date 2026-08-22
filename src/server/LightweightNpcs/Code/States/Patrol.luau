local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local PatrolData = ServerStorage.PatrolData
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local Patrol = {}
local function MoveToward(agent, targetPos)
	local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
	local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
	local dir = flatTarget - flatAgentPos
	agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
end

function Patrol:ExitPatrolState(agent)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.ai.currentNavigationData = nil
	agent.ai.currentMoveIdx = nil
	agent.ai.worldState:set("patrolling", false)
	agent.ai.currentPlan = nil
	agent.ai.currentGoal = nil
	agent:PlayAnimation("idle", false, 1, 1)
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
function Patrol:TryPathfind(agent, destination)
	if agent.busy or not destination then
		return false
	end

	agent.busy = true
	local ok, calcPath = pcall(function()
		return agent.ai.pathfinder:findPath(agent.position, destination)
	end)
	agent.busy = false

	if not ok then
		Utility.Warn(`[TryPathfind] findPath errored: {calcPath}`)
		agent.ai.currentNavigationData = nil
		agent:Move(Vector3.zero)
		return false
	end

	-- local col = Color3.fromRGB(
	-- 	RandomModule.GetRandomIntBetween(0, 255),
	-- 	RandomModule.GetRandomIntBetween(0, 255),
	-- 	RandomModule.GetRandomIntBetween(0, 255)
	-- )
	if calcPath.success then
		-- for _, path in calcPath.waypoints do
		-- 	local l = Instance.new("Part", workspace)
		-- 	l.Color = col
		-- 	l.Anchored = true
		-- 	l.CanCollide = false
		-- 	l.Position = path.Position
		-- end
		agent.ai.currentNavigationData = calcPath
		agent.ai.currentMoveIdx = 2
		return true
	end

	agent.ai.currentNavigationData = nil
	agent:Move(Vector3.zero)
	return false
end

local function CanSeeEnemy(npcRecord: LightweightNpcTypes.npcRecordType, dt: number)
	local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
	local perception = npcRecord.ai.perception
	local perceiverPos = npcRecord.position
	local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
	if not perception or not enemyInstanceTags or not perceiverPos or not range then
		return nil
	end

	local target = nil

	local activeHumans = Utility.GetTagInstancesInWorkspace("NPC")

	for _, playerCharacter in Utility.GetTagInstancesInWorkspace("Player") do
		table.insert(activeHumans, playerCharacter)
	end

	-- prune out of distance characters
	for idx, humanModel: Model in activeHumans do
		local dist = (humanModel:GetPivot().Position - npcRecord.position).Magnitude

		if (dist > range) or humanModel == npcRecord.serverRig then
			-- swap to back and pop
			activeHumans[idx], activeHumans[#activeHumans] = activeHumans[#activeHumans], activeHumans[idx]
			table.remove(activeHumans)
		end
	end

	for _, model: Model in activeHumans do
		for _, tag in enemyInstanceTags do
			if CollectionService:HasTag(model, tag) then
				local targetId = model:GetAttribute("npcId") or model.Name
				local detected, gain = perception:processVisualDetection(
					targetId,
					npcRecord.hrp.Position,
					npcRecord.hrp.CFrame.LookVector,
					model:GetPivot().Position
				)

				local awarenessState = perception:getAwarenessState(targetId)

				if detected and awarenessState == "combat" then
					target = model
					return target
				end
			end
		end
	end

	return nil
end

function Patrol:Update(agent, context)
	local dt = context.dt
	local seesTarget = CanSeeEnemy(agent, dt)
	if seesTarget then
		agent.ai.worldState:set("hasTarget", true)
		agent.ai.currentTarget = seesTarget
		warn("AI sees enemy")
		self:ExitPatrolState(agent)
		return false
	end
	agent.ai.perception:update(dt)
	-- 1. Set patrol route if none set.
	if not agent.ai.currentNavigationData and not agent.busy then
		local success = self:TryPathfind(agent, self:GetNextPatrolPoint(agent))
		if not success then
			self:ExitPatrolState(agent)
			return false
		end
	end

	--

	-- 2. If waypoints not set, the path cannot be navigated
	local waypoints = agent.ai.currentNavigationData and agent.ai.currentNavigationData.waypoints
	if not waypoints then
		if agent.busy then
			return true
		end
		self:ExitPatrolState(agent)
		return false
	end

	local nextWaypoint = waypoints[agent.ai.currentMoveIdx]
	if not nextWaypoint then
		if agent.busy then
			return true
		end
		self:ExitPatrolState(agent)
		return false
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
			local success = self:TryPathfind(agent, self:GetNextPatrolPoint(agent))
			if not success then
				agent:Move(Vector3.zero)
				return false
			end
			return success
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
			MoveToward(agent, nextWaypoint.Position)
		end
	else
		MoveToward(agent, nextWaypoint.Position)
		agent:PlayAnimation("walk", false, 1, 1)
	end

	return true
end
return Patrol
