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

		if not agent.ai.currentNavigationData then
			agent.ai.pathfinder:Run(GetNextPatrolPoint(agent))
			agent.ai.currentNavigationData = true
		end

		agent.ai.pathfinder:Run()
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
		defaultState = npcData.DefaultStateName,
		defaultStateData = npcRecord.defaultStateData,
		currentNavigationIndex = nil,
		currentNavigationData = nil,
		jumpFinishedSignal = SignalModule.new(),
		moveFinishedSignal = SignalModule.new(),
		jumpRequested = false,
	}

	npcRecord.ai.pathfinder = NoobPath.new(
		npcRecord.serverRig,
		{
			WaypointSpacing = 10,
			AgentRadius = 3,
			AgentHeight = 6,
			AgentCanClimb = false,
		} :: Path.AgentParams,
		-- Custom move function
		function(targetPos: Vector3)
			local Break = false
			local C
			C = npcRecord.ai.pathfinder.Overide:Connect(function()
				C:Disconnect()
				Break = true
			end)

			task.defer(function()
				while not Break do
					local toTarget = targetPos - npcRecord.position
					local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
					local dist = flatDir.Magnitude

					if dist <= 2 then
						break
					end

					npcRecord:Move(flatDir.Unit)
					task.wait()
				end

				if not Break then
					npcRecord.ai.moveFinishedSignal:Fire(true)
				end
			end)
		end,
		function()
			if npcRecord.isOnGround then
				npcRecord.ai.jumpRequested = true
				npcRecord:Jump()
			end
		end,
		npcRecord.ai.jumpFinishedSignal,
		npcRecord.ai.moveFinishedSignal
	)
	npcRecord.ai.pathfinder.Speed = HumanConstants.WALKSPEED
	npcRecord.ai.pathfinder.Visualize = true

	npcRecord.ai.moveFinishedSignal:Connect(function()
		npcRecord:Move(Vector3.zero)
		warn("MOVE FINISHED")
	end)

	npcRecord.ai.pathfinder.Reached:Connect(function()
		warn("GOAL REAHCED")

		if npcRecord.ai.worldState.patrolling then
			npcRecord.ai.pathfinder:Run(GetNextPatrolPoint(npcRecord))
		end
	end)

	npcRecord.ai.navigation = Navigation.Navigation.new({
		gridSize = 4,
		maxIterations = 10000,
		moveSpeed = HumanConstants.WALKSPEED,
		minCoverHeight = 3,
		heightTolerance = 6,
		maxSlope = 50,
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
