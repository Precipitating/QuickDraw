local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerSoundHandler = require(script.Parent.Parent.Parent.Sound.ServerSoundHandler)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local CommonNPCData = require(ReplicatedStorage.Shared.NPCData.NPCs.CommonNPCData)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local NPCHealth = {}

function NPCHealth:UpdateHealth(npcRecord: LightweightNpcTypes.npcRecordType, damageTaken: number, attacker: any)
	if npcRecord.invincible then
		return
	end
	npcRecord.hitPoints = math.clamp(npcRecord.hitPoints + damageTaken, 0, HumanConstants.MAX_HP)

	-- There's a loop that handles onDeath event being called, don't add more entries to it.
	if npcRecord.hitPoints <= 0 then
		npcRecord.killedBy = attacker
		return
	end
end
function NPCHealth:UpdateLimbHealth(
	npcRecord: LightweightNpcTypes.npcRecordType,
	limbHit: number,
	damageTaken: number,
	attacker: any
)
	if npcRecord.invincible then
		return
	end

	-- Early returns
	------------------------------------------------------------------------------------------------
	local bodyParts = npcRecord.bodyParts
	if not bodyParts then
		Utility.Warn(`NPC id:{npcRecord.npcId} cannot update limb health! missing`)
		return
	end

	if not bodyParts[limbHit] then
		Utility.Warn(`NPC id:{npcRecord.npcId} limb doesn't exist in their table!`)
		return
	end

	------------------------------------------------------------------------------------------------
	local maxLimbHP = CommonNPCData.LIMB_HEALTH[limbHit]
	local limbData = bodyParts[limbHit]
	local hp = limbData.HP

	-- 1. Update Limb HP
	limbData.HP = math.clamp(hp + damageTaken, HumanConstants.LIMB_DISMEMBER_HP, maxLimbHP)

	-- 2. Determine if we need to dismember/disable a limb and call it
	if limbData.HP <= HumanConstants.LIMB_DISMEMBER_HP then
		if CommonNPCData.SAFE_LIMBS_FROM_DISMEMBERING[limbHit] then
			return
		end
		npcRecord.onDismemberLimb:Fire(limbHit)
		--
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"LimbDismember",
			npcRecord.instance and npcRecord.instance:GetPivot().Position,
			{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
		)
	elseif limbData.HP <= HumanConstants.LIMB_DISABLE_HP then
		if CommonNPCData.CRUCIAL_LIMBS[limbHit] then
			npcRecord.killedBy = attacker
			npcRecord.hitPoints = 0
			return
		end
		if CommonNPCData.SAFE_LIMBS_FROM_DISABLING[limbHit] then
			return
		end
		npcRecord.onDisableLimb:Fire(limbHit)
		--
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"BoneSnap",
			npcRecord.instance and npcRecord.instance:GetPivot().Position,
			{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
		)
	end
end

function NPCHealth:SetInvincibleFor(npcRecord: LightweightNpcTypes.npcRecordType, duration: number)
	local isDead = npcRecord.npcState == NpcStateModule.Dying
	if isDead then
		return
	end

	-- 1. Set invincible on server and apply visuals on client (blue highlight on character)
	npcRecord.invincible = true
	npcRecord:AddClientEvent({ id = "InvincibleToggle", state = true })

	-- 2. Disable invincibility after a set duration
	task.delay(duration, function()
		npcRecord.invincible = false
		npcRecord:AddClientEvent({ id = "InvincibleToggle", state = false })
	end)
end

function NPCHealth:HealAll(npcRecord: LightweightNpcTypes.npcRecordType)
	local bodyParts = npcRecord.bodyParts
	if not bodyParts then
		Utility.Warn(`NPC id:{npcRecord.npcId} cannot update limb health! missing`)
		return
	end

	-- 1. Set all limbs to be collidable/query enabled (to re-enable hitboxes)
	for limbId, limbData in bodyParts do
		local partRef = limbData.Part
		local hp = limbData.HP

		if not partRef or not hp then
			Utility.Warn(`Cannot heal {LimbsEnum[limbId]}, missing a part/hp reference in its table`)
			continue
		end

		limbData.HP = CommonNPCData.LIMB_HEALTH[limbId]
		partRef.CanQuery = true
		partRef.CanCollide = true
	end

	npcRecord.legless = false

	-- 2. Replicate this to client manually (visuals)
	npcRecord:AddClientEvent({ id = "HealAll" })
end

return NPCHealth
