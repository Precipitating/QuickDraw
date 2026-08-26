local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ActionResult = require(script.Parent.ActionResult)
local NPCPoses = require(ServerScriptService.Server.LightweightNpcs.Code.NPCPoses)
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Attack = {}

local function CanStillSeeTarget(agent: LightweightNpcTypes.npcRecordType, dt: number)
	local target = agent.ai.currentTarget
	if not target then
		return false
	end

	local perception = agent.ai.perception
	local currentTargetPosition = target:GetPivot().Position

	local targetId = target:GetAttribute("npcId") or target.Name
	local detected, gain = perception:processVisualDetection(
		targetId,
		agent.hrp.Position,
		agent.hrp.CFrame.LookVector,
		currentTargetPosition
	)

	local awarenessState = perception:getAwarenessState(targetId)
	return detected, awarenessState
end

local function ExitAttackState(agent)
	agent.ai.perception:clearAwareness(agent.npcId)
	agent.ai.currentTarget = nil
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero
	-- Stop tool holding animation if ran (should be on second animation channel)
	agent:StopAnimationChannel(2)
	NPCPoses:ResetPose(agent)
	if not agent.legless then
		agent:PlayAnimation("idle", false, 1, 1)
	else
		agent:PlayAnimation("crawlidle", false, 1, 1)
	end
end

function Attack:Update(agent, context)
	-- Target should be a model
	local target = agent.ai.currentTarget
	local dt = context.dt

	-- Early returns
	if not target then
		ExitAttackState(agent)
		return ActionResult.Success
	end

	if not agent.ai.worldState:get("canShoot") then
		Utility.Warn(`No ammo left to attack!`)
		ExitAttackState(agent)
		return ActionResult.Failed
	end

	-- 1. Determine if we can still see the target, and exit if not
	local detected, currentState = CanStillSeeTarget(agent, dt)
	agent.ai.perception:update(dt)

	-- 1.2 Check if target is dead to exit state, so NPC doesn't keep shooting thin air
	if target:HasTag("Dead") then
		ExitAttackState(agent)
		return ActionResult.Success
	end
	--
	-- 1.3 Seek state if not combat state
	if not detected and currentState ~= "combat" then
		agent.ai.lastSeenTarget = target
		agent.ai.worldState:set("lostTarget", true)
		ExitAttackState(agent)
		return ActionResult.Success
	end

	-- 2. Smoothly rotate to face target
	local enemyPosition = target:GetPivot().Position
	local dir = enemyPosition - agent.hrp.Position
	if dir.Magnitude > 0.001 then
		agent.targetAngle = MathUtils:PlayerVecToAngle(dir)
	end
	--

	-- 3. Shoot at target

	if agent.currentEquipped and not agent.legless then
		agent:PlayAnimation("toolhold", false, 2, 1)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	-- 3.1 Check if we've waited longer than gun's shot delay
	local currentWeaponData = agent.currentEquippedData
	if not currentWeaponData then
		return ActionResult.Failed
	end
	local shotDelay = currentWeaponData.ShotDelay
	local currTime = os.clock()
	local lastShot = currTime - agent.ai.lastShot

	-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! --
	-- 3.2 If waited long enough, shoot

	if lastShot >= shotDelay then
		if currentState == "combat" and detected then
			-- 3.3 Get shoot position on server
			local rightHand = agent.bodyParts[LimbsEnum.RightHand] and agent.bodyParts[LimbsEnum.RightHand].Part
			if rightHand then
				local rightHandAttachment: Attachment = rightHand:FindFirstChild("RightGripAttachment")
				local muzzleOffset: CFrame = agent.data.muzzleOffset
				local finalMuzzleCFrame = rightHandAttachment.WorldCFrame * muzzleOffset
				agent.data.shootPoint = finalMuzzleCFrame

				local targetPos = target:GetPivot().Position

				local debug = Instance.new("Part", workspace)
				debug.Anchored = true
				debug.Material = Enum.Material.Neon
				debug.CFrame = finalMuzzleCFrame
				debug.Size = Vector3.new(0.5, 0.5, 0.5)
				debug.CanCollide = false
				debug.CanQuery = false

				if currentWeaponData.GunType == "Shotgun" then
					NPCWeaponsClass:SpreadShot(agent, targetPos)
				else
					NPCWeaponsClass:SingleShot(agent, targetPos)
				end

				agent.ai.lastShot = currTime
			end
		end
	end

	warn("Attacking, awareness:", currentState)
	return ActionResult.Running
end

return Attack
