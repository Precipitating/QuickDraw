local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CommonStateLogic = require(ServerScriptService.Server.LightweightNpcs.Code.States.CommonStateLogic)
local Hunt = require(ServerScriptService.Server.LightweightNpcs.Code.States.Hunt)
local StayInValidRange = require(ServerScriptService.Server.LightweightNpcs.Code.States.StayInValidRange)
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
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local planner = Planner.new({ maxEvaluationsPerTick = 10 })
local NPCAI = {}

-- NOTE: these Actions are module-level, so every NPC shares them. They carry no per-NPC state
-- (no cooldowns / markStarted / interrupts); per-NPC state lives on npcRecord.ai and npcRecord.data.
-- Each executeFn is polled once per think and returns Running / Success / Failed.

local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { hasTarget = false },
	effects = { hasTarget = true },
	executeFn = function(agent, context)
		return Patrol:Update(agent, context)
	end,
})

local reload = Action.new({
	name = "Reload",
	cost = 1,
	preconditions = { canShoot = false },
	effects = { canShoot = true },
	executeFn = function(agent, context)
		return Reload:Update(agent, context)
	end,
})

local attack = Action.new({
	name = "Attack",
	cost = 1,
	preconditions = { hasTarget = true, atSafeDistance = true },
	effects = { hasTarget = false },
	executeFn = function(agent, context)
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

local stayWithinRange = Action.new({
	name = "StayWithinRange",
	cost = 1,
	preconditions = { atSafeDistance = false },
	effects = { atSafeDistance = true },
	executeFn = function(agent, context)
		return StayInValidRange:Update(agent, context)
	end,
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

local hunt = Action.new({
	name = "Hunt",
	cost = 1,
	preconditions = { hasTarget = true },
	effects = { hasTarget = false },
	executeFn = function(agent, context)
		return Hunt:Update(agent, context)
	end,
})

planner:registerActions({ patrol, stayWithinRange, seek, attack, reload, provoked, hunt })

function NPCAI:ResetWorldState(npcRecord: LightweightNpcTypes.npcRecordType)
	local ai = npcRecord.ai
	ai.pathRequestId = (ai.pathRequestId or 0) + 1 -- discard any in-flight findPath
	ai.lastSeenTarget = nil
	ai.lastSeenPosition = nil
	ai.currentMoveIdx = 2
	ai.currentActionIndex = 1
	ai.lookDone = nil
	ai.retryAt = nil
	ai.lookUntil = nil
	ai.lookStepsLeft = nil
	ai.nextLookStep = nil
	ai.repositionCount = nil
	npcRecord.busy = false
	CommonStateLogic.SetCurrentTarget(npcRecord, nil)
	ai.currentNavigationIndex = nil
	ai.currentNavigationData = nil
	ai.currentPlan = nil
	ai.currentGoal = nil

	ai.worldState:set("atSafeDistance", true)

	ai.worldState:set("hasTarget", false)
	ai.worldState:set("lostTarget", false)
	ai.worldState:set("canShoot", true)
	ai.worldState:set("provoked", false)
end

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
		lastSeenTarget = nil,
		factionData = npcData,
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
		currentNavigationIndex = nil,
		currentNavigationData = nil,
		pathRequestId = 0,
		lastShot = 0,
		goals = nil,
		jumpRequested = false,
	}

	-- Obstruction check: returns true when the view is BLOCKED (Perception:canSee treats true as obstructed).
	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude
	sightParams.FilterDescendantsInstances = { npcRecord.serverRig }

	npcRecord.ai.perception:setObstructionCheck(function(from, to)
		local result = workspace:Raycast(from, to - from, sightParams)
		if not result then
			return false -- nothing in the way
		end

		-- Resolve to the ancestor Model so hits on accessories/tools still count as the character
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and (model:HasTag("NPC") or model:HasTag("Player") or model:HasTag("Animal")) then
			return false -- hit another character on the way to the target, not a wall
		end
		return true
	end)

	npcRecord.ai.pathfinder = PathfindingAdapter.new({
		agentRadius = 3,
		agentHeight = 5,
		agentCanJump = true,
		costs = {
			{ name = "Plastic", cost = math.huge },
			{ name = "SmoothPlastic", cost = math.huge },
			{ name = "Wood", cost = math.huge },
			{ name = "WoodPlanks", cost = math.huge },
		},
	})

	-- GOALS
	local patrolGoal = Goal.new({
		name = "Patrol",
		desiredState = { hasTarget = true },
		priority = 1,
		isValidFn = function(state)
			return state:get("hasTarget") == false
				and not CommonStateLogic.GetCurrentTarget(npcRecord)
				and npcData.DefaultStateName == "Patrol"
		end,
	})

	local attackGoal = Goal.new({
		name = "Attack",
		desiredState = { hasTarget = false },
		priority = 3,
		isValidFn = function(state)
			return state:get("hasTarget") and state:get("atSafeDistance")
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

	local stayWithinRangeGoal = Goal.new({
		name = "StayWithinRange",
		desiredState = { atSafeDistance = true },
		priority = 4.5,
		isValidFn = function(state)
			return not state:get("atSafeDistance")
		end,
	})

	-- This is a state that should not change when entered
	local huntGoal = Goal.new({
		name = "Hunt",
		desiredState = { hasTarget = false },
		priority = 5,
		isValidFn = function(state)
			return state:get("defaultState") == "Hunt" and state:get("hasTarget")
		end,
	})

	npcRecord.ai.goals = { patrolGoal, stayWithinRangeGoal, attackGoal, seekGoal, reloadGoal, provokedGoal, huntGoal }

	-- Reset first, then plan, so the initial plan isn't immediately wiped
	self:ResetWorldState(npcRecord)

	local plan, selectedGoal = planner:planBestGoal(npcRecord.ai.worldState, npcRecord.ai.goals, npcRecord)
	if plan.success then
		npcRecord.ai.currentPlan = plan
		npcRecord.ai.currentGoal = selectedGoal
	end
end

return NPCAI
