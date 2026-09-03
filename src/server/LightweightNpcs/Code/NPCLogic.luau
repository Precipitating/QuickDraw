local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ActionResult = require(ServerScriptService.Server.LightweightNpcs.Code.States.ActionResult)
local Attack = require(ServerScriptService.Server.LightweightNpcs.Code.States.Attack)
local CommonStateLogic = require(ServerScriptService.Server.LightweightNpcs.Code.States.CommonStateLogic)
local Patrol = require(ServerScriptService.Server.LightweightNpcs.Code.States.Patrol)
local Provoked = require(ServerScriptService.Server.LightweightNpcs.Code.States.Provoked)
local Reload = require(ServerScriptService.Server.LightweightNpcs.Code.States.Reload)
local Seek = require(ServerScriptService.Server.LightweightNpcs.Code.States.Seek)
local StayInValidRange = require(ServerScriptService.Server.LightweightNpcs.Code.States.StayInValidRange)
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
local NPC_CULL_DISTANCE = 400
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
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
	local defaultState = npcRecord.ai.worldState:get("defaultState")

	if defaultState == "Patrol" then
		npcRecord.ai.worldState:set("hasTarget", false)
		npcRecord.ai.currentTarget = nil
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
		npcRecord.onPoseChange:Fire("crawlidle", 1)
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
		if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
			Utility.Warn("NPC should stop all actions")
			npcRecord:Move(Vector3.zero)
			npcRecord.velocity = Vector3.zero
			return
		end

		--
		local ai = npcRecord.ai
		ai.perception:update(dt)

		-- Replan if state changed or we have no valid plan
		if ai.worldState:isDirty() or not ai.currentPlan or not ai.currentPlan.success then
			local plan, selectedGoal = npcRecord.ai.planner:planBestGoal(ai.worldState, npcRecord.ai.goals, npcRecord)

			if plan.success then
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
			if ai.currentActionIndex > #ai.currentPlan.actions then
				-- revert states
				for key, value in currentAction.effects._data do
					ai.worldState:set(key, not value)
					print(`Failed state: {key}, {value}`)
				end
				ai.currentPlan = nil
				ai.currentGoal = nil
				ai.currentActionIndex = 1
			end
		elseif result == ActionResult.Running then
			-- Continue running
		end

		if npcRecord.data.forceExitState then
			npcRecord.data.forceExitState()
			npcRecord.data.forceExitState = nil
		end

		-- 	if tick() > npcRecord.data.nextMove then
		-- 		if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
		-- 			return
		-- 		end

		-- 		npcRecord.data.nextMove = tick() + 0.5 + math.random()

		-- 		if math.random() > 0.5 then
		-- 			--idle
		-- 			npcRecord:Move(Vector3.zero)

		-- 			if npcRecord.legless then
		-- 				npcRecord:PlayAnimation("crawlidle", false, 1, 1)
		-- 			else
		-- 				npcRecord:PlayAnimation("idle", false, 1, 1)
		-- 			end
		-- 		else
		-- 			--run
		-- 			local ang = math.random() * math.pi * 2
		-- 			npcRecord:Move(MathUtils:PlayerAngleToVec(ang))

		-- 			if npcRecord.legless then
		-- 				npcRecord:PlayAnimation("crawlwalk", false, 1, 1)
		-- 			else
		-- 				npcRecord:PlayAnimation("walk", false, 1, 1)
		-- 			end
		-- 		end

		-- 		if npcRecord.currentEquipped and not npcRecord.legless then
		-- 			npcRecord:PlayAnimation("toolhold", false, 2, 1)
		-- 		else
		-- 			npcRecord:StopAnimationChannel(2)
		-- 		end
		-- 	end
	end)

	--
	npcRecord.onDismemberLimb:Connect(function(limbToDestroy: number)
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
			warn(LimbsEnum[limbHit])

			NPCHealth:UpdateLimbHealth(npcRecord, limbHit, -totalDmg, attacker)
			NPCHealth:UpdateHealth(npcRecord, -totalDmg, attacker)
			npcRecord:AddClientEvent({
				id = "LimbHit",
				limb = limbHit,
				position = shotPos,
				normal = shotPosNormal,
				attacker = attacker,
			})
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
				warn("NPC On Hit: Missing damage type")
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
	end)

	npcRecord.onDeath:Connect(function()
		if npcRecord.npcState == NpcStateModule.Dying then
			return
		end
		npcRecord.npcState = NpcStateModule.Dying
		warn("onDeath called")

		-- Change collision group so its untouchable
		for _, bodyPart in npcRecord.bodyParts do
			local part = bodyPart.Part
			if not part then
				continue
			end

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
	end)

	npcRecord.onPoseChange:Connect(function(poseName: string, channel: number?)
		if not npcRecord or not npcRecord.poses or not npcRecord.poses[poseName] then
			Utility.Warn(`[onPoseChange] Cannot change pose, missing a pose ref`)
			return
		end
		NPCPoses:ChangePose(npcRecord, poseName, channel)
	end)

	npcRecord.onImpulse:Connect(function(force: Vector3)
		local lastImpulsed = npcRecord.data and npcRecord.data.lastImpulse
		if lastImpulsed and lastImpulsed - os.clock() > 1 then
			return
		end
		npcRecord.data.lastImpulse = os.clock()

		NPCPhysics:ApplyImpulse(npcRecord, force)
	end)

	InitializeOnSpawn(npcRecord)
	npcRecord.onBumpIntoWall:Connect(function(instance)
		if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
			Utility.Warn("NPC should stop all actions")
			return
		end
		local now = os.clock()
		local lastBumped = npcRecord.data.lastBumped

		-- reduce bump spam
		if lastBumped and now - lastBumped <= 1 then
			return
		end

		npcRecord.data.lastBumped = now

		local currentStateName = npcRecord.ai and npcRecord.ai.currentGoal and npcRecord.ai.currentGoal.name

		if not currentStateName then
			return
		end

		-- Attempt to get unstuck through random movements
		npcRecord:Jump()
		local ang = RandomModule.GetRandom() * math.pi * 2
		npcRecord:Move(MathUtils:PlayerAngleToVec(ang))

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
		elseif currentStateName == "StayWithinRange" then
			-- Force a new path to be calculated
			npcRecord.ai.currentNavigationData = nil
		end
	end)
end

return NPCLogic
