local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanSignals = require(ServerScriptService.Server.Classes.Human.HumanSignals)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local NPCPoses = require(ServerScriptService.Server.LightweightNpcs.Code.NPCPoses)
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)

local TOOLHOLD_REFRESH = 1
local THROW_CHANCE = 0.2

local Attack = {}

local function PlayVoice(agent, lineName: string, variants: number?)
	local suffix = if variants then RandomModule.GetRandomIntBetween(1, variants) else ""
	ServerSoundHandler:Play3DNPCVoiceline(
		nil,
		`{lineName}{suffix}{agent.npcType}`,
		agent.npcSound,
		{ MaxDistance = 150 }
	)
end

function Attack:ExitAttackState(agent: LightweightNpcTypes.npcRecordType)
	CommonStateLogic.SetCurrentTarget(agent, nil)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	agent:StopAnimationChannel(2) -- tool hold lives on channel 2
	agent.data.nextToolHoldRefresh = nil
	NPCPoses:ResetPose(agent)
	if agent.legless then
		agent.onPoseChange:Fire("crawlidle")
	end
	CommonStateLogic.PlayLocomotion(agent, "idle")
end

local function Finish(agent, result)
	Attack:ExitAttackState(agent)
	return result
end

function Attack:Update(agent: LightweightNpcTypes.npcRecordType, context)
	if agent.data.forceExitState then
		return Finish(agent, ActionResult.Failed)
	end

	local ai = agent.ai
	local target = CommonStateLogic.GetCurrentTarget(agent)
	if not target or not target.Parent or target:HasTag("Dead") then
		return Finish(agent, ActionResult.Success)
	end

	if not ai.worldState:get("canShoot") then
		return Finish(agent, ActionResult.Success)
	end

	-- 1. Can we still see them?
	local hrp = agent.hrp
	local enemyPosition = target:GetPivot().Position
	local perception = ai.perception
	local targetId = target:GetAttribute("npcId") or target.Name

	local detected = perception:processVisualDetection(targetId, hrp.Position, hrp.CFrame.LookVector, enemyPosition)
	local awareness = perception:getAwarenessState(targetId)

	if not detected and awareness ~= "combat" then
		ai.lastSeenTarget = target
		ai.worldState:set("lostTarget", true)
		PlayVoice(agent, "RangedAILostSight1")
		return Finish(agent, ActionResult.Success)
	end

	-- 2. Attack range
	local factionData = ai.factionData
	local minDist = factionData and factionData.MinAttackDistance
	local maxDist = factionData and factionData.MaxAttackDistance
	if minDist and maxDist then
		local dist = (enemyPosition - hrp.Position).Magnitude
		if dist <= minDist or dist >= maxDist then
			PlayVoice(agent, if dist <= minDist then "RangedAIBackOff" else "RangedAITooFar", 3)
			ai.lastSeenTarget = target
			ai.worldState:set("atSafeDistance", false)
			return Finish(agent, ActionResult.Success)
		end
	end

	-- 3. Face target
	local dir = enemyPosition - hrp.Position
	if dir.Magnitude > 0.001 then
		agent.targetAngle = MathUtils:PlayerVecToAngle(dir)
	end

	local now = os.clock()
	if agent.currentEquipped and not agent.legless and now >= (agent.data.nextToolHoldRefresh or 0) then
		agent.data.nextToolHoldRefresh = now + TOOLHOLD_REFRESH
		agent:PlayAnimation("toolhold", false, 2, 2)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	-- 4. Shoot or throw
	local weapon = agent.currentEquippedData
	if not weapon then
		return ActionResult.Failed
	end

	if now - ai.lastShot < weapon.ShotDelay or not detected or awareness ~= "combat" then
		return ActionResult.Running
	end

	if RandomModule.GetRandom() <= THROW_CHANCE and NPCWeaponsClass:ThrowThrowable(agent, enemyPosition) then
		agent.data.lastThrown = now
		ai.lastShot = now
		return ActionResult.Running
	end

	local rightHandData = agent.bodyParts[LimbsEnum.RightHand]
	local rightHand = rightHandData and rightHandData.Part
	if not rightHand then
		return ActionResult.Running
	end

	local grip = rightHand:FindFirstChild("RightGripAttachment")
	local gripCFrame = if grip and grip:IsA("Attachment") then grip.WorldCFrame else rightHand.CFrame
	agent.data.shootPoint = gripCFrame * CFrame.new(0, 0.5, -1)

	if weapon.GunType == "Shotgun" then
		NPCWeaponsClass:SpreadShot(agent, enemyPosition)
	else
		NPCWeaponsClass:SingleShot(agent, enemyPosition)
	end

	HumanSignals.ApplyImpulseToClient:Fire(
		nil,
		agent.instance,
		Vector3.new(0, 1, 0) * weapon.GunRecoil,
		rightHand.Position - Vector3.new(0, 1, 0),
		"NPCRecoil"
	)
	ai.lastShot = now

	return ActionResult.Running
end

return Attack
