local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local Provoked = {}
local AGGRO_TIME = 3

function Provoked:ExitProvokedState(agent: LightweightNpcTypes.npcRecordType)
	agent.data.shotPosition = nil
	agent.data.lastProvoked = nil
end

function Provoked:Update(agent: LightweightNpcTypes.npcRecordType, context)
	Utility.Warn(`Provoked`)
	local dt = context.dt

	-- 1. Look towards shoot direction
	local shotPos = agent.data.shotPosition
	local dir = (shotPos - agent.position).Unit
	agent.targetAngle = MathUtils:PlayerVecToAngle(dir)

	-- 2. Set animations and stop moving
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	if not agent.legless then
		agent:PlayAnimation("idle", false, 1, 1)
	else
		agent:PlayAnimation("crawlidle", false, 1, 1)
	end

	-- 3. Check if we can see any enemies
	local seesTarget = CommonStateLogic.CanSeeEnemy(agent, dt)
	-- 3.1 If so, return success, meaning provoked = false, and let the plan go to Attack state
	if seesTarget then
		agent.ai.currentTarget = seesTarget
		Utility.Warn("Provoked AI sees enemy")
		return ActionResult.Success
	end

	-- 3.2 If looking at direction and we don't see an enemy for AGGRO_TIME seconds, exit and let plan handle the next state. (Should be Patrol)
	local timeSinceProvoke = os.clock() - agent.data.lastProvoked
	if timeSinceProvoke >= AGGRO_TIME then
		Utility.Warn("Provoked AI look time over, back to patrol")
		self:ExitProvokedState(agent)
		return ActionResult.Success
	end

	return ActionResult.Running
end

return Provoked
