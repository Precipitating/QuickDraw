local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Patrol = require(ServerScriptService.Server.LightweightNpcs.Code.States.Patrol)
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

local planner = Planner.new({ performanceMode = true, maxEvaluationsPerTick = 10 })
local NPCAI = {}

local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false, defaultState = "Patrol" },
	effects = { patrolling = true },
	interruptible = true,
	onInterrupt = function(agent, context)
		print("Interrupted patrol")
	end,

	executeFn = function(agent, context)
		return Patrol:Update(agent)
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
	preconditions = { hasTarget = true, atSafeDistance = false },
	effects = { atSafeDistance = true },

	executeFn = function(agent, context) end,
})

planner:registerActions({ patrol, retreat, seek, throwThrowable, shootGun })

function NPCAI:Initialize(npcRecord: LightweightNpcTypes.npcRecordType)
	local npcData = NPCTypes[npcRecord.npcType]

	npcRecord.ai = {
		worldState = State.new({
			health = npcRecord.hitPoints,
			atSafeDistance = true,
			hasTarget = false,
			patrolling = false,
			targetKilled = false,
			defaultState = npcData.DefaultStateName,
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
		currentActionIndex = 1,
		planner = planner,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
		currentNavigationIndex = nil,
		currentNavigationData = nil,
		goals = nil,
		jumpRequested = false,
	}

	npcRecord.ai.pathfinder = PathfindingAdapter.new({
		agentRadius = 6,
		agentHeight = 6,
		agentCanJump = true,
		costs = {
			{ name = "Plastic", cost = math.huge },
		},
	})

	local patrolGoal = Goal.new({
		name = "Patrol",
		desiredState = { patrolling = true },
		priority = 1,
	})
	npcRecord.ai.goals = { patrolGoal }

	local plan, selectedGoal = planner:planBestGoal(npcRecord.ai.worldState, npcRecord.ai.goals, npcRecord)

	if plan.success then
		npcRecord.ai.currentPlan = plan
		npcRecord.ai.currentGoal = selectedGoal
	end
end

return NPCAI
