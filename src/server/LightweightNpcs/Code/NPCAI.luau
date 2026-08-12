local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Action = require(ReplicatedStorage.Shared.GoalAI.Action)
local Planner = require(ReplicatedStorage.Shared.GoalAI.Planner)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local planner = Planner.new()
local NPCAI = {}

local patrol = Action.new({
	name = "Patrol",
	cost = 1,
	preconditions = { enemySpotted = false, dead = false },
	effects = { patrolling = true },

	executeFn = function(agent, context) end,
})
local shootGun = Action.new({
	name = "ShootGun",
	cost = 2,
	preconditions = { enemySpotted = true },
	effects = { enemyKilled = true },

	executeFn = function(agent, context) end,
})
local throwThrowable = Action.new({
	name = "ThrowThrowable",
	cost = 1,
	preconditions = { enemySpotted = true },
	effects = { enemyKilled = true },

	executeFn = function(agent, context) end,
})
local seek = Action.new({
	name = "Seek",
	cost = 1,
	preconditions = { enemySpotted = false },
	effects = { enemySpotted = true },

	executeFn = function(agent, context) end,
})

local retreat = Action.new({
	name = "Retreat",
	cost = 1,
	preconditions = { enemySpotted = true },
	effects = { enemyKilled = true },

	executeFn = function(agent, context) end,
})

function NPCAI:Initialize(npcRecord: LightweightNpcTypes.npcRecordType)
	planner:registerAction({ patrol, retreat, seek, throwThrowable, shootGun })
end

return NPCAI
