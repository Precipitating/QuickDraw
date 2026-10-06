local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCHealth = require(ServerScriptService.Server.LightweightNpcs.Code.NPCHealth)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local StayInValidRange = require(script.Parent.StayInValidRange)
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)

local TOOLHOLD_REFRESH = 1

local Hunt = {}

-- NOTE: every exit kills the NPC (original behavior, kept as-is).
function Hunt:ExitHuntState(agent: LightweightNpcTypes.npcRecordType)
	CommonStateLogic.SetCurrentTarget(agent, nil)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent.ai.currentNavigationData = nil
	agent.data.nextToolHoldRefresh = nil
	NPCHealth:UpdateHealth(agent, -99999)
end

function Hunt:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local ai = agent.ai
	local target = CommonStateLogic.GetCurrentTarget(agent)
	if not target then
		self:ExitHuntState(agent)
		return ActionResult.Failed
	end
	if not target.Parent or target:HasTag("Dead") then
		self:ExitHuntState(agent)
		return ActionResult.Success
	end

	-- 1. Mid-route: keep following until we arrive, then re-evaluate range
	if ai.currentNavigationData then
		if CommonStateLogic.FollowPath(agent, true) ~= "moving" then
			ai.currentNavigationData = nil
			ai.currentMoveIdx = 2
		end
		return ActionResult.Running
	end

	-- 2. Out of throwing range: path to a spot inside the band
	local enemyPosition = target:GetPivot().Position
	local factionData = ai.factionData
	local minDist = factionData and factionData.MinAttackDistance
	local maxDist = factionData and factionData.MaxAttackDistance

	if minDist and maxDist then
		local dist = (enemyPosition - agent.hrp.Position).Magnitude
		if dist <= minDist or dist >= maxDist then
			ai.lastSeenTarget = target
			if not StayInValidRange:GeneratePathWithinRange(agent) then
				return ActionResult.Failed -- executor backs off, then retries
			end
			return ActionResult.Running
		end
	end

	-- 3. In position: stand, face, throw
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	CommonStateLogic.PlayLocomotion(agent, "idle")

	local now = os.clock()
	if agent.storedThrowable and not agent.legless and now >= (agent.data.nextToolHoldRefresh or 0) then
		agent.data.nextToolHoldRefresh = now + TOOLHOLD_REFRESH
		agent:PlayAnimation("toolhold", false, 2, 2)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	local dir = enemyPosition - agent.hrp.Position
	if dir.Magnitude > 0.001 then
		agent.targetAngle = MathUtils:PlayerVecToAngle(dir)
	end

	if NPCWeaponsClass:ThrowThrowable(agent, enemyPosition) then
		agent.data.lastThrown = now
	end

	return ActionResult.Running
end

return Hunt
