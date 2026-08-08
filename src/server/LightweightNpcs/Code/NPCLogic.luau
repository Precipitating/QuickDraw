local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationIds = require(ReplicatedStorage.Shared.AnimationData.AnimationIds)
local CommonNPCData = require(ReplicatedStorage.Shared.NPCData.NPCs.CommonNPCData)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local NPCHealth = require(script.Parent.NPCHealth)
local NpcTypes = require(script.Parent.NpcTypes)
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local NPC_CULL_DISTANCE = 400
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local NPCLogic = {}

--
local CrawlIdleAnim = Instance.new("Animation")
CrawlIdleAnim.AnimationId = `rbxassetid://{AnimationIds.LeglessGunIdle}`
--

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
function NPCLogic:SetupServerAnims(npcRecord: NpcTypes.npcRecordType)
	if not npcRecord.animator then
		Utility.Warn("[ NPCLogic:SetupServerAnims] Animator ref missing")
		return
	end

	npcRecord.poses["Crawl"] = npcRecord.animator:LoadAnimation(CrawlIdleAnim)
end

local function InitializeOnSpawn(npcRecord: NpcTypes.npcRecordType)
	NPCLogic:SetupServerAnims(npcRecord)

	--
	npcRecord:AddClientEvent({ id = "Initialize" })
	NPCHealth:SetInvincibleFor(npcRecord, 5)
end

function NPCLogic:HitByGunshot(npcRecord: NpcTypes.npcRecordType, gunShotData: ClassTypes.GunShotDamage)
	local canAffectShooter: boolean? = gunShotData.CanAffectShooter
	local raycastResult: RaycastResult = gunShotData.RaycastResult
	local damageInflicted: number = gunShotData.Damage
	local attacker: Player? = gunShotData.Shooter
	local limbEnum = LimbsEnum[raycastResult and raycastResult.Instance and raycastResult.Instance.Name]

	if not raycastResult or not damageInflicted then
		Utility.Warn(`[NPCLogic:HitByGunshot] Missing raycast result or damage values`)
		return
	end

	npcRecord.onLimbHit:Fire(damageInflicted, limbEnum, raycastResult.Position, raycastResult.Normal, attacker)
end
local function IsLimbOut(limb)
	return limb.State == "Dismembered" or limb.State == "Disabled"
end

function NPCLogic:AffectLimbAndChildren(
	npcRecord: NpcTypes.npcRecordType,
	rootLimbId: number,
	newState: string,
	eventId: string
)
	local rootLimb = npcRecord.bodyParts and npcRecord.bodyParts[rootLimbId]

	if not rootLimb or not rootLimb.Part then
		Utility.Warn(("[npcRecord.%s] Limb reference missing"):format(eventId))
		return
	end

	if rootLimb.State then
		rootLimb.State = newState
	end

	npcRecord:AddClientEvent({ id = eventId, limb = rootLimbId })

	rootLimb.Part.Transparency = 0.5
	rootLimb.Part.CanQuery = false
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
		childLimb.Part.CanQuery = false
		childLimb.Part.CanCollide = false

		if childLimb.State then
			childLimb.State = newState
		end
	end

	-- Crawl if both legs are dismembered/disabled
	if
		IsLimbOut(npcRecord.bodyParts[LimbsEnum.LeftUpperLeg])
			and IsLimbOut(npcRecord.bodyParts[LimbsEnum.RightUpperLeg])
		or IsLimbOut(npcRecord.bodyParts[LimbsEnum.RightUpperLeg])
			and IsLimbOut(npcRecord.bodyParts[LimbsEnum.RightLowerLeg])
	then
		-- Will make client NPCs play crawl anims
		npcRecord.legless = true
		-- Force crawl server pose so we can somewhat emulate its hitboxes
		npcRecord.onPoseChange:Fire("Crawl")
	end
end

function NPCLogic:HitByInflictingBullet(npcRecord: NpcTypes.npcRecordType, inflictingData: ClassTypes.InflictingDamage)
	local spreadParticleName: string? = inflictingData.SpreadParticleName
	local spreadDuration: number? = inflictingData.SpreadDuration
	local limbHit: BasePart? = inflictingData.LimbHit
	local attacker: Player? = inflictingData.Shooter
	local damageInflicted = inflictingData.Damage

	if not limbHit then
		Utility.Warn("[NPCLogic:HitByInflictingBullet] Missing limb reference")
		return
	end

	if spreadDuration then
		task.spawn(function()
			for _ = 1, spreadDuration do
				if npcRecord.npcState == NpcStateModule.Dying then
					return
				end
				npcRecord.onLimbHit:Fire(damageInflicted, LimbsEnum[limbHit.Name], nil, nil, attacker)
				if spreadParticleName then
					npcRecord:AddClientEvent({
						id = "SpreadParticle",
						ParticleName = spreadParticleName,
						Duration = spreadDuration,
						limbName = limbHit.Name,
					})
				end
				task.wait(1)
			end
		end)
	end
end

function NPCLogic:ChangePose(npcRecord: NpcTypes.npcRecordType, poseName: string)
	if not npcRecord.animator then
		Utility.Warn("Missing server NPC animator ref")
		return
	end

	local animator: Animator = npcRecord.animator

	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.5 or 0)
	end

	npcRecord.poses[poseName]:Play(0.5, 1, 1)
end

function NPCLogic:OnSpawn(npcRecord: NpcTypes.npcRecordType)
	InitializeOnSpawn(npcRecord)
	npcRecord.onThink:Connect(function(dt)
		if tick() > npcRecord.data.nextMove then
			if npcRecord.npcState == NpcStateModule.Dying then
				return
			end

			npcRecord.data.nextMove = tick() + 0.5 + math.random()

			if math.random() > 0.5 then
				--idle
				npcRecord:Move(Vector3.zero)

				if npcRecord.legless then
					npcRecord:PlayAnimation("crawlidle", false, 1, 1)
				else
					npcRecord:PlayAnimation("idle", false, 1, 1)
				end
			else
				--run
				local ang = math.random() * math.pi * 2
				npcRecord:Move(MathUtils:PlayerAngleToVec(ang))

				if npcRecord.legless then
					npcRecord:PlayAnimation("crawlwalk", false, 1, 1)
				else
					npcRecord:PlayAnimation("walk", false, 1, 1)
				end
			end
		end
	end)
	npcRecord.onDismemberLimb:Connect(function(limbToDestroy: number)
		self:AffectLimbAndChildren(npcRecord, limbToDestroy, "Dismembered", "DismemberLimb")
	end)

	npcRecord.onDisableLimb:Connect(function(limbToDisable: number)
		self:AffectLimbAndChildren(npcRecord, limbToDisable, "Disabled", "DisableLimb")
	end)

	npcRecord.onLimbHit:Connect(
		function(damage: number, limbHit: number, shotPos: Vector3?, shotPosNormal: Vector3?, attacker: any?)
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

	npcRecord.onHit:Connect(
		function(
			damageData: ClassTypes.InflictingDamage | ClassTypes.GunShotDamage | ClassTypes.TrapDamage | ClassTypes.BargeDamage
		)
			if not damageData.Type then
				warn("NPC On Hit: Missing damage type")
				return
			end

			if npcRecord.invincible then
				return
			end
			local character: Model? = npcRecord.instance
			local damageType = damageData.Type
			if damageType == "Shot" then
				self:HitByGunshot(npcRecord, damageData)
			elseif damageType == "Inflict" then
				self:HitByInflictingBullet(npcRecord, damageData)
			end

			if character then
				ServerSoundHandler:Play3DOneShotToOthers(
					nil,
					"BulletHitGroan",
					character:GetPivot().Position,
					{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
				)
			end
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

	npcRecord.onDeath:Connect(function(attacker: any?)
		if npcRecord.npcState == NpcStateModule.Dying then
			return
		end
		npcRecord.npcState = NpcStateModule.Dying
		warn("onDeath called")
		if npcRecord.instance then
			npcRecord:Move(Vector3.zero)
			npcRecord:AddClientEvent({ id = "Dead", attacker = attacker })
			ServerSoundHandler:Play3DOneShotToOthers(
				nil,
				"HumanDeathGasp",
				npcRecord.instance and npcRecord.instance:GetPivot().Position,
				{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
			)
		end
	end)

	npcRecord.onPoseChange:Connect(function(poseName: string)
		if not npcRecord or not npcRecord.poses or not npcRecord.poses[poseName] then
			Utility.Warn(`[onPoseChange] Cannot change pose, missing a pose ref`)
			return
		end
		self:ChangePose(npcRecord, poseName)
	end)

	-- npcRecord.onBumpIntoWall:Connect(function(instance)
	-- 	--send an event to clients if we bump into something
	-- 	if npcRecord.instance then
	-- 		--This costs RECV, but flashes the NPCS white for fun
	-- 		npcRecord:AddClientEvent({ id = "Bump" })
	-- 	end
	-- 	npcRecord:Move(Vector3.zero)
	-- 	npcRecord:PlayAnimation("idle", false, 1, 1)
	-- end)
end

return NPCLogic
