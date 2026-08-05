local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local NpcTypes = require(script.Parent.NpcTypes)
local NPCHealth = {}
NPCHealth.LimbHealth = {
	[LimbsEnum.Head] = 50,
	[LimbsEnum.UpperTorso] = 85,
	[LimbsEnum.LowerTorso] = 70,
	[LimbsEnum.LeftUpperArm] = 60,
	[LimbsEnum.LeftLowerArm] = 60,
	[LimbsEnum.RightUpperArm] = 999,
	[LimbsEnum.RightLowerArm] = 999,
	[LimbsEnum.LeftUpperLeg] = 40,
	[LimbsEnum.LeftLowerLeg] = 40,
	[LimbsEnum.RightUpperLeg] = 40,
	[LimbsEnum.RightLowerLeg] = 40,
}
function NPCHealth:UpdateHealth(npcRecord: NpcTypes.npcRecordType, damageTaken: number, attacker: any)
	npcRecord.hitPoints = math.clamp(npcRecord.hitPoints, 0, HumanConstants.MAX_HP)

	if damageTaken < 0 then
		npcRecord.onHit:Fire(attacker)
	end

	if npcRecord.hitPoints <= 0 then
		npcRecord.onDeath:Fire(attacker)
	end
end
function NPCHealth:UpdateLimbHealth(
	npcRecord: NpcTypes.npcRecordType,
	limbHit: number,
	damageTaken: number,
	attacker: any
)
	------------------------------------------------------------------------------------------------
	local bodyParts = npcRecord.bodyParts
	if not bodyParts then
		Utility.Warn(`NPC id:{npcRecord.npcId} cannot update limb health! missing`)
		return
	end

	if not bodyParts[LimbsEnum[limbHit]] then
		Utility.Warn(`NPC id:{npcRecord.npcId} limb doesn't exist in their table!`)
		return
	end
	------------------------------------------------------------------------------------------------
	local toEnum = LimbsEnum[limbHit]
	local maxLimbHP = self.limbHealth[toEnum]
	local hp = bodyParts[toEnum].HP

	hp += math.clamp(hp + damageTaken, HumanConstants.LIMB_DISMEMBER_HP, maxLimbHP)

	if hp <= HumanConstants.LIMB_DISMEMBER_HP then
		npcRecord.onDismemberLimb:Fire(limbHit)
	elseif hp <= HumanConstants.LIMB_DISABLE_HP then
		npcRecord.onDisableLimb:Fire(limbHit)
	end
end

function NPCHealth:HealAll(npcRecord: NpcTypes.npcRecordType)
	local bodyParts = npcRecord.data.BodyParts
	if not bodyParts then
		Utility.Warn(`NPC id:{npcRecord.npcId} cannot update limb health! missing`)
		return
	end

	for _, limb in bodyParts do
		local toEnum = LimbsEnum[limb.Part.Name]
		limb.HP = self.limbHealth[toEnum]
	end
end

return NPCHealth
