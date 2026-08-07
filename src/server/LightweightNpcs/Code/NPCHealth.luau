local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local NpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.NpcTypes)
local NpcStateModule = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcState)

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

NPCHealth.SafeLimbsFromDisabling = {
	[LimbsEnum.Head] = true,
	[LimbsEnum.UpperTorso] = true,
	[LimbsEnum.LowerTorso] = true,
}
function NPCHealth:UpdateHealth(npcRecord: NpcTypes.npcRecordType, damageTaken: number, attacker: any)
	if npcRecord.invincible then
		return
	end
	npcRecord.hitPoints = math.clamp(npcRecord.hitPoints + damageTaken, 0, HumanConstants.MAX_HP)

	if npcRecord.hitPoints <= 0 then
		npcRecord.onDeath:Fire(attacker)
		return
	end
end
function NPCHealth:UpdateLimbHealth(
	npcRecord: NpcTypes.npcRecordType,
	limbHit: number,
	damageTaken: number,
	attacker: any
)
	if npcRecord.invincible then
		return
	end
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
	local maxLimbHP = self.LimbHealth[limbHit]
	local hp = bodyParts[limbHit].HP

	bodyParts[limbHit].HP = math.clamp(hp + damageTaken, HumanConstants.LIMB_DISMEMBER_HP, maxLimbHP)

	if bodyParts[limbHit].HP <= HumanConstants.LIMB_DISMEMBER_HP then
		npcRecord.onDismemberLimb:Fire(limbHit)
	elseif bodyParts[limbHit].HP <= HumanConstants.LIMB_DISABLE_HP then
		if self.SafeLimbsFromDisabling[limbHit] then
			return
		end
		npcRecord.onDisableLimb:Fire(limbHit)
	end
end

function NPCHealth:SetInvincibleFor(npcRecord: NpcTypes.npcRecordType, duration: number)
	local isDead = npcRecord.npcState == NpcStateModule.Dying
	if isDead then
		return
	end

	npcRecord.invincible = true
	npcRecord:AddClientEvent({ id = "InvincibleToggle", state = true })

	task.delay(duration, function()
		npcRecord.invincible = false
		npcRecord:AddClientEvent({ id = "InvincibleToggle", state = false })
	end)
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
