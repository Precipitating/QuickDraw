local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local AGGRO_TIME = 3
local Provoked = {}

function Provoked:ExitProvokedState(agent: LightweightNpcTypes.npcRecordType)
	agent.data.shotPosition = nil
	agent.data.lastProvoked = nil
end

local function Finish(agent, result)
	Provoked:ExitProvokedState(agent)
	return result
end

function Provoked:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local data = agent.data
	local lastProvoked = data.lastProvoked
	if not lastProvoked then
		return Finish(agent, ActionResult.Success) -- nothing to react to
	end

	-- 1. Look toward the shot, if we know where it came from
	local shotPos = data.shotPosition
	if shotPos then
		local offset = shotPos - agent.position
		if offset.Magnitude > 0.001 then
			agent.targetAngle = MathUtils:PlayerVecToAngle(offset)
		end
	end

	-- 2. Stand still
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	CommonStateLogic.PlayLocomotion(agent, "idle")

	-- 3. Enemy in sight: hand over to Attack with a real target
	local seen = CommonStateLogic.CanSeeEnemy(agent, context.dt)
	if seen then
		CommonStateLogic.SetCurrentTarget(agent, seen)
		return Finish(agent, ActionResult.Success)
	end

	-- 4. Nothing found after AGGRO_TIME: give up and let the plan pick the next state
	if os.clock() - lastProvoked >= AGGRO_TIME then
		return Finish(agent, ActionResult.Success)
	end

	return ActionResult.Running
end

return Provoked
