local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Goal = require(ReplicatedStorage.Shared.GoalAI.Goal)
local Navigation = require(ReplicatedStorage.Shared.GoalAI.Navigation)
local SignalModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.Signal)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local State = require(ReplicatedStorage.Shared.GoalAI.State)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local NoobPath = require(ReplicatedStorage.Shared.Pathfinding.NoobPath)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PatrolData = ServerStorage.PatrolData
local planner = Planner.new()
local NPCAI = {}

local function CanSeeEnemy(npcRecord: LightweightNpcTypes.npcRecordType)
	local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
	local perception = npcRecord.ai.perception
	local perceiverPos = npcRecord.hrp.Position
	local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
	if not perception or not enemyInstanceTags or not perceiverPos or not range then
		return nil
	end

	local target = nil

	local nearbyObjects = workspace:GetPartBoundsInRadius(npcRecord.hrp.Position, range)

	for _, part in nearbyObjects do
		if not part:IsA("BasePart") then
			continue
		end
		for _, tag in enemyInstanceTags do
			if CollectionService:HasTag(part, tag) and part.Parent then
				target = part.Parent
				return target
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
	navigation:cancelPath()
	local nextWaypoint = GetNextPatrolPoint(agent)
	local possible = navigation:findPath(currPos, nextWaypoint)

	if possible.pathFound then
		agent.ai.isNavigating = nextWaypoint
		navigation:setPath(possible)
	end
end
local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false },
	effects = { patrolling = true },

	executeFn = function(agent, context)
		local navigation = agent.ai.navigation
		local currPos = agent.hrp and agent.hrp.Position
		-- 1. Early Exit: Check for Enemies
		local seesTarget = CanSeeEnemy(agent)
		if seesTarget then
			agent.ai.worldState:set("hasTarget", seesTarget)
			agent.ai.worldState:set("patrolling", false)
			agent.ai.actionStarted = false

			navigation:cancelPath()
			agent.ai.isNavigating = false
			return true
		end

		-- Waypoint set, check and advance until reach destination
		if agent.ai.isNavigating then
			-- Returns true if reached last destination
			if navigation:advanceWaypoint(currPos, 2) then
				agent.ai.isNavigating = false
			else
				-- Not reached end destination
				local currWaypoint = navigation:getNextWaypoint()
				local flatDelta = Vector3.new(currWaypoint.X - currPos.X, 0, currWaypoint.Z - currPos.Z)
				if flatDelta.Magnitude > 0.01 then
					agent:Move(flatDelta.Unit)
				end
				return true
			end
		end

		-- Set new patrol point
		SetNextPatrolPoint(agent, currPos, navigation)

		if not agent.ai.isNavigating then
			warn(`Cant get next patrol point path`)
			return false
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
		jumpFinished = SignalModule.new(),
		moveFinished = SignalModule.new(),
		currentGoal = nil,
		currentPlan = nil,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
	}

	npcRecord.ai.navigation = Navigation.Navigation.new({
		gridSize = 4,
		maxIterations = 100000,
		moveSpeed = 6,
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
