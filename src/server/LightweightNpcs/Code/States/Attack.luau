local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local PatrolData = ServerStorage.PatrolData
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local Attack = {}

local function CanStillSeeTarget(agent)
	local target = agent.ai.currentTarget
	if not target then
		return false
	end

	local perception = agent.ai.perception

	local canSee, _, _ =
		perception:canSee(agent.position, agent.hrp.CFrame.LookVector, target:GetPivot().Position, true)

	return canSee
end

function Attack:Update(agent)
	local target = agent.ai.currentTarget
	agent:PlayAnimation("idle", false, 1, 1)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero

	if not target then
		agent.ai.currentTarget = nil
		agent.ai.worldState:set("hasTarget", false)
		return false
	end

	if not CanStillSeeTarget(agent) then
		agent.ai.currentTarget = nil
		agent.ai.worldState:set("hasTarget", false)
		warn("Lost target")
		return false
	end

	warn("Attacking")

	return true
end

return Attack
