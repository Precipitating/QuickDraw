local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Attack = require(ServerScriptService.Server.LightweightNpcs.Code.States.Attack)
local Patrol = require(ServerScriptService.Server.LightweightNpcs.Code.States.Patrol)
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Goal = require(ReplicatedStorage.Shared.GoalAI.Goal)
local Navigation = require(ReplicatedStorage.Shared.GoalAI.Navigation)
local PathfindingAdapter = require(ReplicatedStorage.Shared.GoalAI.Navigation.PathfindingAdapter)
local SignalModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.Signal)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local State = require(ReplicatedStorage.Shared.GoalAI.State)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
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
		Utility.Warn(`Entered Patrol State`)
		return Patrol:Update(agent, context)
	end,
})
local attack = Action.new({
	name = "Attack",
	cost = 1,
	preconditions = { hasTarget = true },
	effects = { targetKilled = true, attacking = true },

	executeFn = function(agent, context)
		Utility.Warn(`Entered Attack State`)
		Attack:Update(agent, context)
	end,
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

planner:registerActions({ patrol, retreat, seek, attack })

function NPCAI:Initialize(npcRecord: LightweightNpcTypes.npcRecordType)
	local npcData = NPCTypes[npcRecord.npcType]

	npcRecord.ai = {
		worldState = State.new({
			health = npcRecord.hitPoints,
			atSafeDistance = true,
			hasTarget = false,
			patrolling = false,
			seeking = false,
			targetKilled = false,
			defaultState = npcData.DefaultStateName,
		}),
		perception = Perception.new({
			vision = {
				range = npcData.EyeRange,
				angle = 120,
			},
			awareness = {
				decayRate = 5,
				thresholds = { alert = 60, combat = 80 },
			},
		}),

		currentGoal = nil,
		currentPlan = nil,
		currentMoveIdx = 2,
		currentActionIndex = 1,
		planner = planner,
		currentTarget = nil,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
		currentNavigationIndex = nil,
		currentNavigationData = nil,
		lastShot = 0,
		goals = nil,
		jumpRequested = false,
	}
	npcRecord.ai.perception:setObstructionCheck(function(from, to)
		local raycastParams = RaycastParams.new()
		raycastParams.ExcludeInstances = { npcRecord.serverRig }

		local result = workspace:Raycast(from, to - from)

		if result and result.Instance then
			local parent = result.Instance.Parent
			if not parent then
				return true
			end

			if parent:HasTag("NPC") or parent:HasTag("Player") then
				return false
			else
				return true
			end
		else
			return nil
		end
	end)

	npcRecord.ai.pathfinder = PathfindingAdapter.new({
		agentRadius = 6,
		agentHeight = 6,
		agentCanJump = true,
		costs = {
			{ name = "Plastic", cost = math.huge },
		},
	})

	-- GOALS
	local patrolGoal = Goal.new({
		name = "Patrol",
		desiredState = { patrolling = true },
		priority = 1,
		isValidFn = function(state)
			return not state:get("patrolling") and not state:get("hasTarget")
		end,
	})

	local attackGoal = Goal.new({
		name = "Attack",
		desiredState = { attacking = true },
		priority = 2,
		isValidFn = function(state)
			return state:get("hasTarget") == true
		end,
	})
	local seekGoal = Goal.new({
		name = "Seek",
		desiredState = { seeking = true },
		priority = 2,
		isValidFn = function(state)
			return state:get("hasTarget") == false and state:get("Seeking")
		end,
	})
	npcRecord.ai.goals = { patrolGoal, attackGoal }

	local plan, selectedGoal = planner:planBestGoal(npcRecord.ai.worldState, npcRecord.ai.goals, npcRecord)

	if plan.success then
		npcRecord.ai.currentPlan = plan
		npcRecord.ai.currentGoal = selectedGoal
	end
end

return NPCAI
