local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Goal = require(ReplicatedStorage.Shared.GoalAI.Goal)
local Navigation = require(ReplicatedStorage.Shared.GoalAI.Navigation)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local State = require(ReplicatedStorage.Shared.GoalAI.State)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local PatrolData = ServerStorage.PatrolData
local planner = Planner.new()
local NPCAI = {}

local function CanSeeEnemy(npcRecord: LightweightNpcTypes.npcRecordType)
	local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
	local perception = npcRecord.ai.perception
	local perceiverPos = npcRecord.HRP.Position
	local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
	if not perception or not enemyInstanceTags or not perceiverPos or not range then
		return nil
	end

	local target = nil

	local nearbyObjects = workspace:GetPartBoundsInRadius(npcRecord.HRP.Position, range)

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

local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false },
	effects = { patrolling = true },

	executeFn = function(agent, context)
		--1. Get waypoints to traverse to
		local nextPatrolPoint = PatrolData[agent.ai.defaultStateData]
		if not nextPatrolPoint then
			return false
		end
		nextPatrolPoint = nextPatrolPoint:GetChildren()

		-- 2. Find next path
		local navigation = agent.ai.navigation

		-- 3. Move to path
		agent.ai.actionStarted = true
		for _, patrolPart in nextPatrolPoint do
			local seesTarget = CanSeeEnemy(agent)

			if seesTarget then
				agent.ai.worldState.hasTarget = seesTarget
				agent.ai.actionStarted = false
				agent.ai.worldState.patrolling = false
				return true
			end
			local path = navigation:findPath(agent.HRP.Position, patrolPart.Position)
			if path.pathFound then
				navigation:setPath(path)
				local waypoint = navigation:getNextWaypoint()
				agent:Move(waypoint)
			end
		end

		agent.ai.actionStarted = false
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
		navigation = Navigation.Navigation.new({
			gridSize = 4,
			maxIterations = 500,
			moveSpeed = 6,
			minCoverHeight = 3,
		}),

		currentGoal = nil,
		currentPlan = nil,
		planStep = 1,
		actionStarted = false,
		actionResult = nil,
		stateDirty = true,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcData.DefaultStateData,
	}

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
