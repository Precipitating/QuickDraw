local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Human = require(ServerScriptService.Server.Classes.Human.Human)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Goal = require(ReplicatedStorage.Shared.GoalAI.Goal)
local Navigation = require(ReplicatedStorage.Shared.GoalAI.Navigation)
local PathfindingAdapter = require(ReplicatedStorage.Shared.GoalAI.Navigation.PathfindingAdapter)
local SignalModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.Signal)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local State = require(ReplicatedStorage.Shared.GoalAI.State)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local NoobPath = require(ReplicatedStorage.Shared.Pathfinding.NoobPath)
local Path = require(ReplicatedStorage.Shared.Pathfinding.Path)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PatrolData = ServerStorage.PatrolData
local planner = Planner.new({ performanceMode = true, maxEvaluationsPerTick = 10 })
local NPCAI = {}

local function CanSeeEnemy(npcRecord: LightweightNpcTypes.npcRecordType)
	local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
	local perception = npcRecord.ai.perception
	local perceiverPos = npcRecord.position
	local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
	if not perception or not enemyInstanceTags or not perceiverPos or not range then
		return nil
	end

	local target = nil

	local nearbyObjects = workspace:GetPartBoundsInRadius(npcRecord.position, range)

	for _, part in nearbyObjects do
		if not part:IsA("BasePart") then
			continue
		end
		for _, tag in enemyInstanceTags do
			if CollectionService:HasTag(part, tag) and part.Parent then
				if
					perception:canSee(
						npcRecord.position,
						npcRecord.hrp.CFrame.LookVector,
						part.Parent:GetPivot().Position,
						true
					)
				then
					target = part.Parent
					return target
				end
			end
		end
	end

	return nil
end

local function flatDistance(posA: Vector3, posB: Vector3): number
	return Vector3.new(posA.X - posB.X, 0, posA.Z - posB.Z).Magnitude
end

local function GetNextPatrolPoint(npcRecord: LightweightNpcTypes.npcRecordType)
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

local function SetNextPatrolPoint(agent, currPos, navigation)
	local pathfinder = agent.ai.pathfinder

	if not pathfinder then
		Utility.Warn(`Missing pathfinder`)
		return false
	end

	local nextWaypoint = GetNextPatrolPoint(agent)

	local prt = Instance.new("Part", workspace)
	prt.Anchored = true
	prt.Position = nextWaypoint
	prt.Color = Color3.fromRGB(0, 255, 94)
	prt.CanCollide = false

	pathfinder:Run(nextWaypoint)
	return true
end
local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false },
	effects = { patrolling = true },

	executeFn = function(agent, context)
		local navigation = agent.ai.navigation
		local ai = agent.ai

		local seesTarget = CanSeeEnemy(agent)
		if seesTarget then
			agent.ai.worldState:set("hasTarget", seesTarget)
			agent.ai.worldState:set("patrolling", false)
			agent:Move(Vector3.zero)
			return false
		end

		if not agent.ai.currentNavigationData and not agent.busy then
			agent.busy = true
			local nextDestination = GetNextPatrolPoint(agent)
			local calcPath = agent.ai.pathfinder:findPath(agent.position, nextDestination)

			if calcPath.success then
				agent.ai.currentNavigationData = calcPath
				agent.ai.currentMoveIdx = 2
				local col = Color3.fromRGB(
					RandomModule.GetRandomIntBetween(0, 255),
					RandomModule.GetRandomIntBetween(0, 255),
					RandomModule.GetRandomIntBetween(0, 255)
				)
				for _, wp in calcPath.waypoints do
					local l = Instance.new("Part", workspace)
					l.Position = wp.Position
					l.Anchored = true
					l.Color = col
					l.CanCollide = false
				end

				agent.busy = false
				return true
			else
				agent.busy = false
				agent:Move(Vector3.zero)
				return false
			end
		end

		local currentPathfindData = agent.ai.currentNavigationData
		local waypoints = currentPathfindData and currentPathfindData.waypoints
		if not waypoints then
			agent:Move(Vector3.zero)
			return false
		end

		local nextPos = waypoints and waypoints[agent.ai.currentMoveIdx]
		if not nextPos then
			return false
		end

		local flattened = Vector3.new(nextPos.Position.X, 0, nextPos.Position.Z)
		local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
		local dist = (flattened - flatAgentPos).Magnitude

		if dist <= 2 then
			agent.ai.currentMoveIdx += 1
			nextPos = waypoints[agent.ai.currentMoveIdx]

			if not nextPos then
				local nextDestination = GetNextPatrolPoint(agent)
				local calcPath = agent.ai.pathfinder:findPath(agent.position, nextDestination)

				if calcPath.success then
					agent.ai.currentNavigationData = calcPath
					agent.ai.currentMoveIdx = 2
				else
					agent.ai.currentNavigationData = nil
					agent:Move(Vector3.zero)
				end

				return true
			end

			flattened = Vector3.new(nextPos.Position.X, 0, nextPos.Position.Z)
		end

		if nextPos.Action == Enum.PathWaypointAction.Jump then
			if agent.isOnGround then
				agent:Jump()
				agent.ai.currentMoveIdx += 1
			else
				-- still walking toward the jump point while airborne/not-yet-grounded;
				-- don't leave motionVector frozen
				local dir = (flattened - flatAgentPos)
				if dir.Magnitude > 0.001 then
					agent:Move(dir.Unit)
				else
					agent:Move(Vector3.zero)
				end
			end
		else
			local dir = (flattened - flatAgentPos)
			if dir.Magnitude > 0.001 then
				agent:Move(dir.Unit)
			else
				agent:Move(Vector3.zero)
			end
		end

		return true
	end,
})
local shootGun = Action.new({
	name = "ShootGun",
	cost = 2,
	preconditions = { hasTarget = true },
	effects = { targetKilled = true },

	executeFn = function(agent, context) end,
})
local throwThrowable = Action.new({
	name = "ThrowThrowable",
	cost = 1,
	preconditions = { hasTarget = true },
	effects = { targetKilled = true },

	executeFn = function(agent, context) end,
})
local seek = Action.new({
	name = "Seek",
	cost = 1,
	preconditions = { hasTarget = false },
	effects = { hasTarget = true },

	executeFn = function(agent, context) end,
})

local retreat = Action.new({
	name = "Retreat",
	cost = 1,
	preconditions = { hasTarget = true },
	effects = { atSafeDistance = true },

	executeFn = function(agent, context) end,
})

planner:registerActions({ patrol, retreat, seek, throwThrowable, shootGun })

function NPCAI:Initialize(npcRecord: LightweightNpcTypes.npcRecordType)
	local npcData = NPCTypes[npcRecord.npcType]

	npcRecord.ai = {
		worldState = State.new({
			health = npcRecord.hitPoints,
			enemyKilled = false,
			atSafeDistance = true,
			hasTarget = false,
			patrolling = false,
			targetKilled = false,
		}),
		perception = Perception.new({
			vision = {
				range = npcData.EyeRange,
				angle = 120,
			},
		}),
		currentGoal = nil,
		currentPlan = nil,
		currentMoveIdx = 2,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
		currentNavigationIndex = nil,
		currentNavigationData = nil,
		jumpFinishedSignal = SignalModule.new(),
		moveFinishedSignal = SignalModule.new(),
		jumpRequested = false,
	}

	npcRecord.ai.navigation = Navigation.Navigation.new({
		gridSize = 4,
		maxIterations = 10000,
		moveSpeed = HumanConstants.WALKSPEED,
		minCoverHeight = 3,
		heightTolerance = 6,
		maxSlope = 50,
	})

	npcRecord.ai.pathfinder = PathfindingAdapter.new({
		agentRadius = 3,
		agentHeight = 6,
		agentCanJump = true,
		costs = {
			{ name = "Plastic", cost = 20 },
		},
	})

	local defaultDesiredState = nil

	if npcData.DefaultStateName == "Patrol" then
		defaultDesiredState = { patrolling = true }
	end

	local defaultStateGoal = Goal.new({
		name = npcData.DefaultStateName,
		desiredState = defaultDesiredState,
		priority = 1,
	})

	npcRecord.ai.currentPlan = planner:plan(npcRecord.ai.worldState, defaultStateGoal)
end

return NPCAI
