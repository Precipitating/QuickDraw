local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ActionResult = require(ServerScriptService.Server.LightweightNpcs.Code.States.ActionResult)
local CommonStateLogic = require(ServerScriptService.Server.LightweightNpcs.Code.States.CommonStateLogic)
local Patrol = require(ServerScriptService.Server.LightweightNpcs.Code.States.Patrol)
local Reload = require(ServerScriptService.Server.LightweightNpcs.Code.States.Reload)
local Seek = require(ServerScriptService.Server.LightweightNpcs.Code.States.Seek)
local StayInValidRange = require(ServerScriptService.Server.LightweightNpcs.Code.States.StayInValidRange)
local PlayerSignals = require(ServerScriptService.Server.Managers.Player.PlayerSignals)
local AwardHandler = require(script.Parent.Parent.Parent.AwardHandler.AwardHandler)
local CommonNPCData = require(ReplicatedStorage.Shared.NPCData.NPCs.CommonNPCData)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClassTypes = require(script.Parent.Parent.Parent.Classes.ClassTypes)
local ServerSoundHandler = require(script.Parent.Parent.Parent.Sound.ServerSoundHandler)
local NPCHealth = require(script.Parent.NPCHealth)
local NPCWeaponsClass = require(script.Parent.NPCWeaponsClass)
local LightweightNpcTypes = require(script.Parent.LightweightNpcTypes)
local NPCAI = require(script.Parent.NPCAI)
local NPCPhysics = require(script.Parent.NPCPhysics)
local NPCPoses = require(script.Parent.NPCPoses)
local NPC_CULL_DISTANCE = 500
local BUMP_DELAY = 1
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local NPCLogic = {}

--
local CrawlIdleAnim = Instance.new("Animation")
CrawlIdleAnim.AnimationId = `rbxassetid://122940383806072`
local ToolHold = Instance.new("Animation")
ToolHold.AnimationId = "http://www.roblox.com/asset/?id=507768375"

local LimbDamageMultiplier = {
	[LimbsEnum.Head] = 2.5,
	[LimbsEnum.UpperTorso] = 1.05,
	[LimbsEnum.LowerTorso] = 1.05,

	[LimbsEnum.LeftUpperArm] = 0.49,
	[LimbsEnum.LeftLowerArm] = 0.49,
	[LimbsEnum.RightUpperArm] = 0.49,
	[LimbsEnum.RightLowerArm] = 0.49,

	[LimbsEnum.LeftUpperLeg] = 0.7,
	[LimbsEnum.LeftLowerLeg] = 0.7,
	[LimbsEnum.RightUpperLeg] = 0.7,
	[LimbsEnum.RightLowerLeg] = 0.7,
}

local LEAVE_HANDLERS = {
	StayWithinRange = function(npc)
		StayInValidRange:ExitStayInValidRangeState(npc)
		npc.ai.repositionCount = nil
	end,
	Seek = function(npc)
		Seek:ExitSeekState(npc)
	end,
	Reload = function(npc)
		Reload:ExitReloadState(npc)
	end,
}
function NPCLogic:SetupServerAnims(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord.animator then
		Utility.Warn("[ NPCLogic:SetupServerAnims] Animator ref missing")
		return
	end

	npcRecord.poses["crawlidle"] = npcRecord.animator:LoadAnimation(CrawlIdleAnim)
	npcRecord.poses["toolhold"] = npcRecord.animator:LoadAnimation(ToolHold)
end

local function InitializeOnSpawn(npcRecord: LightweightNpcTypes.npcRecordType)
	NPCLogic:SetupServerAnims(npcRecord)
	--
	npcRecord:AddClientEvent({ id = "Initialize" })
	NPCWeaponsClass:InitializeWeaponClass(npcRecord)
	NPCWeaponsClass:EquipWeapon(npcRecord)
	NPCHealth:SetInvincibleFor(npcRecord, 5)
	NPCAI:Initialize(npcRecord)
end

local function AddWantedTag(npcRecord: LightweightNpcTypes.npcRecordType, attacker: Model? | Player?)
	if not attacker then
		return
	end

	if npcRecord.faction == "Sheriff" then
		if attacker:IsA("Player") then
			local character = attacker.Character
			if character then
				character:AddTag("Wanted")
			end
		end
	end
end

local function ResetToDefaultState(npcRecord: LightweightNpcTypes.npcRecordType)
	NPCAI:ResetWorldState(npcRecord)
end

function NPCLogic:ApplyBulletEffects(npcRecord: LightweightNpcTypes.npcRecordType, bulletObject: BasePart)
	if not bulletObject or not npcRecord then
		Utility.Warn(`Cannot apply bullet effect to NPC, missing valid arg`)
		return
	end

	if bulletObject:HasTag("CannonBall") then
		local force = 150
		local dir: Vector3 = bulletObject.CFrame.LookVector * force
		--local dirUpBias = dir + Vector3.new(0, 3, 0)
		npcRecord.onImpulse:Fire(dir, function()
			npcRecord.onRagdoll:Fire(5)
		end)
	end
end

function NPCLogic:HitByGunshot(npcRecord: LightweightNpcTypes.npcRecordType, gunShotData: ClassTypes.GunShotDamage)
	local canAffectShooter: boolean? = gunShotData.CanAffectShooter
	local raycastResult: RaycastResult = gunShotData.RaycastResult
	local damage: number = gunShotData.Damage
	local attacker: Player? | Model? = gunShotData.Shooter
	local limbEnum = LimbsEnum[raycastResult and raycastResult.Instance and raycastResult.Instance.Name]

	if not raycastResult or not damage then
		Utility.Warn(`[NPCLogic:HitByGunshot] Missing raycast result or damage values`)
		return
	end

	-- Don't hit himself
	if attacker == npcRecord.instance and canAffectShooter == false then
		return
	end

	-- Add wanted tag if hit sheriff
	AddWantedTag(npcRecord, attacker)

	npcRecord.onLimbHit:Fire(damage, limbEnum, raycastResult.Position, raycastResult.Normal, attacker)

	self:ApplyBulletEffects(npcRecord, gunShotData.CosmeticBulletObject)
end

function NPCLogic:HitByTrap(npcRecord: LightweightNpcTypes.npcRecordType, trapData: ClassTypes.TrapDamage)
	local damageInflicted = trapData.Damage
	local limbHit = trapData.LimbHit
	local attacker = trapData.Shooter

	if attacker then
		if attacker.Player then
			attacker = attacker.Player
		end

		AddWantedTag(npcRecord, attacker)
	end

	npcRecord.onLimbHit:Fire(damageInflicted, LimbsEnum[limbHit.Name], nil, nil, attacker)
end
local function IsLimbOut(limb)
	return limb.State == "Dismembered" or limb.State == "Disabled"
end

function NPCLogic:HitByBarge(npcRecord: LightweightNpcTypes.npcRecordType, bargeData: ClassTypes.BargeDamage)
	local damage: number? = bargeData.Damage
	local limb: BasePart? = bargeData.LimbHit
	local attacker: Player? | Model? = bargeData.Shooter
	if not limb then
		Utility.Warn(`Barge Dmg missing limb hit ref`)
		return
	end

	local limbEnum = LimbsEnum[limb.Name]
	-- Don't hit himself
	if attacker == npcRecord.instance then
		return
	end

	-- Add wanted tag if hit sheriff
	AddWantedTag(npcRecord, attacker)

	npcRecord.onLimbHit:Fire(damage, limbEnum, nil, nil, attacker)
end

function NPCLogic:AffectLimbAndChildren(
	npcRecord: LightweightNpcTypes.npcRecordType,
	rootLimbId: number,
	newState: string,
	eventId: string
)
	local rootLimb = npcRecord.bodyParts and npcRecord.bodyParts[rootLimbId]
	local isDismembered = newState == "Dismembered"
	local isDisabled = newState == "Disabled"
	if not rootLimb or not rootLimb.Part then
		Utility.Warn(("[npcRecord.%s] Limb reference missing"):format(eventId))
		return
	end

	if rootLimb.State then
		rootLimb.State = newState
	end

	npcRecord:AddClientEvent({ id = eventId, limb = rootLimbId })

	rootLimb.Part.Transparency = 0.5
	rootLimb.Part.CanQuery = not isDismembered
	rootLimb.Part.CanCollide = false

	-- affect downstream chain
	local chain = CommonNPCData.LIMB_CHAIN[rootLimbId]
	if not chain then
		return
	end

	for _, childLimbId in chain do
		local childLimb = npcRecord.bodyParts[childLimbId]
		if not childLimb or not childLimb.Part then
			continue
		end

		childLimb.Part.Transparency = 0.5
		childLimb.Part.CanQuery = not isDismembered
		childLimb.Part.CanCollide = false

		if childLimb.State then
			childLimb.State = newState
		end
	end

	-- Crawl if both legs are dismembered/disabled
	if
		IsLimbOut(npcRecord.bodyParts[LimbsEnum.LeftUpperLeg])
			and IsLimbOut(npcRecord.bodyParts[LimbsEnum.RightUpperLeg])
		or IsLimbOut(npcRecord.bodyParts[LimbsEnum.LeftLowerLeg])
			and IsLimbOut(npcRecord.bodyParts[LimbsEnum.RightLowerLeg])
	then
		-- Will make client NPCs play crawl anims
		npcRecord.legless = true
		-- Force crawl server pose so we can somewhat emulate its hitboxes
		npcRecord.onPoseChange:Fire("crawlidle", 0.3)
		npcRecord:StopAnimationChannel(2)
	end
end

function NPCLogic:HitByStatusBullet(npcRecord: LightweightNpcTypes.npcRecordType, statusData: ClassTypes.StatusDamage)
	local spreadParticleName: string? = statusData.SpreadParticle
	local spreadDuration: number? = statusData.SpreadDuration
	local limbHit: BasePart? = statusData.LimbHit
	local attacker: Player? = statusData.Shooter
	local damage = statusData.Damage

	if not limbHit then
		Utility.Warn("[NPCLogic:HitByStatusBullet] Missing limb reference")
		return
	end

	-- Add wanted tag if hit sheriff
	AddWantedTag(npcRecord, attacker)

	if spreadDuration then
		task.spawn(function()
			for _ = 1, spreadDuration do
				if npcRecord.npcState == NpcStateModule.Dying then
					return
				end
				npcRecord.onLimbHit:Fire(damage, LimbsEnum[limbHit.Name], nil, nil, attacker)
				if spreadParticleName then
					npcRecord:AddClientEvent({
						id = "SpreadParticle",
						SpreadParticle = spreadParticleName,
						Duration = spreadDuration,
						-- send limb number to client, reduce some data.
						limbName = LimbsEnum[limbHit.Name],
					})
				end
				task.wait(1)
			end
		end)
	end
end

function NPCLogic:OnSpawn(npcRecord: LightweightNpcTypes.npcRecordType)
	npcRecord.onThink:Connect(function(dt)
		-- Early exits
		local ai = npcRecord.ai
		if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
			--Utility.Warn("NPC should stop all actions")
			npcRecord:Move(Vector3.zero)
			npcRecord.velocity = Vector3.zero
			return
		end
		if ai.retryAt and os.clock() < ai.retryAt then
			return -- idling after a failure (Exit already stopped movement)
		end
		--

		ai.perception:update(dt)

		-- Replan if state changed or we have no valid plan
		if ai.worldState:isDirty() or not ai.currentPlan or not ai.currentPlan.success then
			local plan, selectedGoal = npcRecord.ai.planner:planBestGoal(ai.worldState, npcRecord.ai.goals, npcRecord)

			if plan.success then
				local newName = selectedGoal.name
				local oldName = ai.currentGoal and ai.currentGoal.name
				if oldName ~= newName then
					ai.pathRequestId = (ai.pathRequestId or 0) + 1
					ai.currentNavigationData = nil
					ai.currentMoveIdx = 2
					local leave = oldName and LEAVE_HANDLERS[oldName]
					if leave then
						leave(npcRecord)
					end
				end
				ai.currentPlan = plan
				ai.currentGoal = selectedGoal
				ai.currentActionIndex = 1
			end

			ai.worldState:markClean()
		end

		if not ai.currentPlan or not ai.currentPlan.success then
			ResetToDefaultState(npcRecord)
			return -- nothing achievable right now
		end

		local currentAction = ai.currentPlan.actions[ai.currentActionIndex]
		if not currentAction then
			return -- plan finished; will replan next dirty check, or force one
		end

		local context = { dt = dt }
		local result = currentAction:execute(npcRecord, context)

		-- Action complete, meaning apply effects if all actions ran and so next plan should occur.
		if result == ActionResult.Success then
			if ai.currentPlan and ai.currentPlan.actions then
				ai.currentActionIndex += 1

				if ai.currentActionIndex > #ai.currentPlan.actions then
					-- apply this action's effects when all steps finished
					for key, value in currentAction.effects._data do
						ai.worldState:set(key, value)
						print(`Success state: {key}, {value}`)
					end
					ai.currentPlan = nil
					ai.currentGoal = nil
					ai.currentActionIndex = 1
				end
			end
		elseif result == ActionResult.Failed then
			ai.currentPlan = nil
			ai.currentGoal = nil
			ai.currentActionIndex = 1
			if not npcRecord.data.forceExitState then
				ai.retryAt = os.clock() + 0.5
			end
		elseif result == ActionResult.Running then
			-- Continue running
		end

		if npcRecord.data.forceExitState then
			npcRecord.data.forceExitState()
			npcRecord.data.forceExitState = nil
		end
	end)

	--
	npcRecord.onDismemberLimb:Connect(function(limbToDestroy: number)
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"LimbDismember",
			npcRecord.instance and npcRecord.instance:GetPivot().Position,
			{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
		)
		self:AffectLimbAndChildren(npcRecord, limbToDestroy, "Dismembered", "DismemberLimb")
	end)

	npcRecord.onDisableLimb:Connect(function(limbToDisable: number)
		self:AffectLimbAndChildren(npcRecord, limbToDisable, "Disabled", "DisableLimb")
	end)

	npcRecord.onLimbHit:Connect(
		function(damage: number, limbHit: number, shotPos: Vector3?, shotPosNormal: Vector3?, attacker: any?)
			if npcRecord.npcState == NpcStateModule.Dying then
				return
			end
			local totalDmg = damage * (LimbDamageMultiplier[limbHit] or 1)
			Utility.Warn(LimbsEnum[limbHit])

			NPCHealth:UpdateLimbHealth(npcRecord, limbHit, -totalDmg, attacker)
			NPCHealth:UpdateHealth(npcRecord, -totalDmg, attacker)
			npcRecord:AddClientEvent({
				id = "LimbHit",
				limb = limbHit,
				position = shotPos,
				normal = shotPosNormal,
				attacker = attacker,
			})

			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				"BoneSnap",
				npcRecord.instance and npcRecord.instance:GetPivot().Position,
				{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
			)
		end
	)

	-- Entry for all damage, decides the damage type and executes correct logic
	npcRecord.onHit:Connect(
		function(
			damageData: ClassTypes.StatusDamage | ClassTypes.GunShotDamage | ClassTypes.TrapDamage | ClassTypes.BargeDamage
		)
			-- Early returns
			if npcRecord.npcState == NpcStateModule.Dying then
				return
			end
			if not damageData.Type then
				Utility.Warn("NPC On Hit: Missing damage type")
				return
			end

			if npcRecord.invincible then
				return
			end

			--
			local character: Model? = npcRecord.instance
			local damageType = damageData.Type
			if damageType == "Shot" then
				self:HitByGunshot(npcRecord, damageData)
			elseif damageType == "Status" then
				self:HitByStatusBullet(npcRecord, damageData)
			elseif damageType == "Barge" then
				self:HitByBarge(npcRecord, damageData)
			elseif damageType == "Trap" then
				self:HitByTrap(npcRecord, damageData)
			end

			if character then
				ServerSoundHandler:Play3DOneShotToOthers(
					nil,
					"BulletHitGroan",
					character:GetPivot().Position,
					{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
				)
			end

			-- aggro
			local currentStateName = npcRecord.ai.currentGoal and npcRecord.ai.currentGoal.name

			if currentStateName and currentStateName ~= "Attack" then
				npcRecord.data.forceExitState = function()
					npcRecord.ai.worldState:set("provoked", true)
					if damageData.Type == "Shot" then
						npcRecord.data.shotPosition = damageData.ShotPosition
						npcRecord.data.lastProvoked = os.clock()
					end
				end
			end

			npcRecord:ForceReplicate()
		end
	)

	npcRecord.onCullCheck:Connect(function()
		--Basic culling, but you could technically mask NPCs to individual players
		--or anything else you want to do here
		for key, player in game.Players:GetPlayers() do
			if player.Character and player.Character.PrimaryPart then
				local bubbleVec = npcRecord.position - (player.Character.PrimaryPart :: any).Position

				if bubbleVec.Magnitude < NPC_CULL_DISTANCE then
					npcRecord:SetPlayerVisibleFlag(player, true)
				else
					npcRecord:SetPlayerVisibleFlag(player, false)
				end
			end
		end
	end)

	npcRecord.onRagdoll:Connect(function(duration: number?, onChanged: (() -> ())?)
		NPCPhysics:Ragdoll(npcRecord, duration, onChanged)
		npcRecord:ForceReplicate()
	end)

	npcRecord.onDeath:Connect(function()
		if npcRecord.npcState == NpcStateModule.Dying then
			return
		end
		npcRecord.npcState = NpcStateModule.Dying
		Utility.Warn("onDeath called")
		CommonStateLogic.SetCurrentTarget(npcRecord, nil)
		--NPCPoses:ResetPose(npcRecord)
		-- Change collision group so its untouchable
		for _, bodyPart in npcRecord.bodyParts do
			local part = bodyPart.Part
			if not part then
				continue
			end
			part.Color = Color3.fromRGB(255, 0, 0)

			part.CollisionGroup = "Dead"
		end
		if npcRecord.instance then
			npcRecord:Move(Vector3.zero)
			npcRecord:AddClientEvent({ id = "Dead", attacker = npcRecord.killedBy })
			npcRecord.serverRig:AddTag("Dead")
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				"HumanDeathGasp",
				npcRecord.instance and npcRecord.instance:GetPivot().Position,
				{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
			)

			if npcRecord.killedBy and typeof(npcRecord.killedBy) == "Instance" and npcRecord.killedBy:IsA("Player") then
				AwardHandler.AwardNPCKill(npcRecord.killedBy)
			end
		end

		PlayerSignals.ReduceNPCCounter:Fire(npcRecord.serverRig, npcRecord.faction)
		npcRecord:ForceReplicate()
	end)

	npcRecord.onPoseChange:Connect(function(poseName: string, channel: number?)
		if not npcRecord or not npcRecord.poses or not npcRecord.poses[poseName] then
			Utility.Warn(`[onPoseChange] Cannot change pose, missing a pose ref`)
			return
		end
		NPCPoses:ChangePose(npcRecord, poseName, channel)
		npcRecord:ForceReplicate()
	end)

	npcRecord.onImpulse:Connect(function(force: Vector3, onComplete: (() -> ())?)
		local lastImpulsed = npcRecord.data and npcRecord.data.lastImpulse
		local now = os.clock()

		if lastImpulsed and now - lastImpulsed < BUMP_DELAY then
			return
		end

		npcRecord.data.lastImpulse = now

		NPCPhysics:ApplyImpulse(npcRecord, force)

		if onComplete then
			task.defer(function()
				onComplete()
			end)
		end
		npcRecord:ForceReplicate()
	end)

	InitializeOnSpawn(npcRecord)
	npcRecord.onBumpIntoWall:Connect(function(instance)
		if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
			--Utility.Warn("NPC should stop all actions")
			return
		end
		local now = os.clock()
		local lastBumped = npcRecord.data.lastBumped

		-- reduce bump spam, tries again in 0.5 secs
		if lastBumped and now - lastBumped <= BUMP_DELAY then
			return
		end

		npcRecord.data.lastBumped = now

		local currentStateName = npcRecord.ai and npcRecord.ai.currentGoal and npcRecord.ai.currentGoal.name

		if not currentStateName then
			return
		end

		-- Attempt to get unstuck via random impulses behind/left/right
		local impulseDir = nil
		if RandomModule.GetRandom() > 0.5 then
			impulseDir = -npcRecord.hrp.CFrame.LookVector
		else
			if RandomModule.GetRandom() > 0.5 then
				impulseDir = npcRecord.hrp.CFrame.RightVector
			else
				impulseDir = -npcRecord.hrp.CFrame.RightVector
			end
		end

		npcRecord.hrp.Anchored = false
		npcRecord.onImpulse:Fire(impulseDir * 50, function()
			npcRecord.hrp.Anchored = true
			-- Retry a waypoint path
			if currentStateName == "Patrol" then
				local success = Patrol:TryGetNextPatrolWaypoint(npcRecord)
				if not success then
					Patrol:ExitPatrolState(npcRecord)
				end
			elseif currentStateName == "Seek" and npcRecord.ai.lastSeenTarget then
				local success = Seek:GeneratePathToLastSeenTarget(npcRecord, true)

				if not success then
					Seek:ExitSeekState(npcRecord)
				end
			elseif currentStateName == "StayWithinRange" or currentStateName == "Hunt" then
				-- Force a new path to be calculated
				npcRecord.ai.currentNavigationData = nil
			end
		end)
		npcRecord:ForceReplicate()
	end)
end

return NPCLogic
