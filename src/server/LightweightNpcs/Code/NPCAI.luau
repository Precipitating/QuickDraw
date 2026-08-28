local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attack = require(script.Parent.States.Attack)
local Patrol = require(script.Parent.States.Patrol)
local Provoked = require(script.Parent.States.Provoked)
local Reload = require(script.Parent.States.Reload)
local Seek = require(script.Parent.States.Seek)
local Perception = require(ReplicatedStorage.Shared.GoalAI.AI.Perception)
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Goal = require(ReplicatedStorage.Shared.GoalAI.Goal)
local PathfindingAdapter = require(ReplicatedStorage.Shared.GoalAI.Navigation.PathfindingAdapter)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local State = require(ReplicatedStorage.Shared.GoalAI.State)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local planner = Planner.new({ performanceMode = true, maxEvaluationsPerTick = 10 })
local NPCAI = {}

local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false, defaultState = "Patrol" },
	effects = { hasTarget = true },
	interruptible = true,
	onInterrupt = function(agent, context)
		print("Interrupted patrol")
	end,

	executeFn = function(agent, context)
		Utility.Warn(`Entered Patrol State`)
		return Patrol:Update(agent, context)
	end,
})
local reload = Action.new({
	name = "Reload",
	cost = 1,
	preconditions = { canShoot = false },
	effects = { canShoot = true },
	interruptible = true,
	onInterrupt = function(agent, context)
		print("Interrupted reload")
	end,

	executeFn = function(agent, context)
		Utility.Warn(`Entered Reload State`)
		return Reload:Update(agent, context)
	end,
})
local attack = Action.new({
	name = "Attack",
	cost = 1,
	preconditions = { hasTarget = true },
	effects = { hasTarget = false },

	executeFn = function(agent, context)
		Utility.Warn(`Entered Attack State`)
		return Attack:Update(agent, context)
	end,
})

local seek = Action.new({
	name = "Seek",
	cost = 1,
	preconditions = { hasTarget = false, lostTarget = true },
	effects = { lostTarget = false },

	executeFn = function(agent, context)
		return Seek:Update(agent, context)
	end,
})

local retreat = Action.new({
	name = "Retreat",
	cost = 1,
	preconditions = { hasTarget = true, atSafeDistance = false },
	effects = { atSafeDistance = true },

	executeFn = function(agent, context) end,
})
local provoked = Action.new({
	name = "Provoked",
	cost = 1,
	preconditions = { provoked = true },
	effects = { provoked = false, hasTarget = true },

	executeFn = function(agent, context)
		return Provoked:Update(agent, context)
	end,
})

planner:registerActions({ patrol, retreat, seek, attack, reload, provoked })

function NPCAI:Initialize(npcRecord: LightweightNpcTypes.npcRecordType)
	local npcData = NPCTypes[npcRecord.npcType]

	npcRecord.ai = {
		worldState = State.new({
			health = npcRecord.hitPoints,
			atSafeDistance = true,
			hasTarget = false,
			lostTarget = false,
			canShoot = true,
			defaultState = npcData.DefaultStateName,
		}),
		perception = Perception.new({
			vision = {
				range = npcData.EyeRange,
				angle = 120,
			},
			awareness = {
				decayRate = 10,
				thresholds = { alert = 60, combat = 80 },
			},
		}),

		currentGoal = nil,
		currentPlan = nil,
		currentMoveIdx = 2,
		currentActionIndex = 1,
		planner = planner,
		currentTarget = nil,
		lastSeenTarget = nil,
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
		desiredState = { hasTarget = true },
		priority = 1,
		isValidFn = function(state)
			return not state:get("hasTarget") and not npcRecord.ai.lastSeenTarget
		end,
	})

	local attackGoal = Goal.new({
		name = "Attack",
		desiredState = { hasTarget = false },
		priority = 3,
		isValidFn = function(state)
			return state:get("hasTarget")
		end,
	})
	local seekGoal = Goal.new({
		name = "Seek",
		desiredState = { lostTarget = false },
		priority = 2,
		isValidFn = function(state)
			return state:get("lostTarget") and not state:get("hasTarget") and npcRecord.ai.lastSeenTarget
		end,
	})

	local reloadGoal = Goal.new({
		name = "Reload",
		desiredState = { canShoot = true },
		priority = 4,
		isValidFn = function(state)
			return not state:get("canShoot") and npcRecord.currentEquipped
		end,
	})

	local provokedGoal = Goal.new({
		name = "Provoked",
		desiredState = { provoked = false },
		priority = 4,
		isValidFn = function(state)
			return state:get("provoked")
		end,
	})
	npcRecord.ai.goals = { patrolGoal, attackGoal, seekGoal, reloadGoal, provokedGoal }

	local plan, selectedGoal = planner:planBestGoal(npcRecord.ai.worldState, npcRecord.ai.goals, npcRecord)
	if plan.success then
		npcRecord.ai.currentPlan = plan
		npcRecord.ai.currentGoal = selectedGoal
	end
end

return NPCAI
