local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCHealth = require(ServerScriptService.Server.LightweightNpcs.Code.NPCHealth)
local ActionResult = require(script.Parent.ActionResult)
local StayInValidRange = require(script.Parent.StayInValidRange)
local NPCPoses = require(ServerScriptService.Server.LightweightNpcs.Code.NPCPoses)
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Hunt = {}

function Hunt:ExitHuntState(agent: LightweightNpcTypes.npcRecordType)
	agent.ai.currentTarget = nil
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	NPCHealth:UpdateHealth(agent, -99999)
end

function Hunt:Update(agent: LightweightNpcTypes.npcRecordType, context)
	if agent.data.forceExitState then
		self:ExitHuntState(agent)
		return ActionResult.Failed
	end

	if agent.ai.currentNavigationData then
		StayInValidRange:MoveTowardsWaypoints(agent, context, function()
			agent.ai.currentNavigationData = nil
		end)
		return ActionResult.Running
	end
	-- Target should be a model
	local target = agent.ai.currentTarget
	local dt = context.dt

	-- Early returns
	if not target then
		self:ExitHuntState(agent)
		return ActionResult.Failed
	end

	-- 1.2 Check if target is dead to exit state, so NPC doesn't keep shooting thin air
	if target:HasTag("Dead") then
		self:ExitHuntState(agent)
		return ActionResult.Success
	end
	--
	-- 1.4 Return early if not within Hunt range
	local enemyPosition = target:GetPivot().Position
	local minDist = agent.ai.factionData and agent.ai.factionData.MinAttackDistance
	local maxDist = agent.ai.factionData and agent.ai.factionData.MaxAttackDistance

	if minDist and maxDist then
		local dist = (enemyPosition - agent.hrp.Position).Magnitude
		if dist <= minDist or dist >= maxDist then
			-- too far/close to target, change state to StayInValidRange
			Utility.Warn(`Target out of range, moving`)
			agent.ai.lastSeenTarget = agent.ai.currentTarget
			StayInValidRange:GeneratePathWithinRange(agent)
			return ActionResult.Running
		end
	end

	-- IN POSITION TO THROW
	-- 2. Smoothly rotate to face target
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	if not agent.legless then
		agent:PlayAnimation("idle", false, 1, 1)
	else
		agent:PlayAnimation("crawlidle", false, 1, 1)
	end

	if agent.storedThrowable and not agent.legless then
		agent:PlayAnimation("toolhold", false, 2, 2)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	local dir = enemyPosition - agent.hrp.Position
	if dir.Magnitude > 0.001 then
		agent.targetAngle = MathUtils:PlayerVecToAngle(dir)
	end
	--
	-- 3. Throw at target

	local thrown = NPCWeaponsClass:ThrowThrowable(agent, enemyPosition)
	if thrown then
		agent.data.lastThrown = os.clock()
	end
	return ActionResult.Running
end

return Hunt
