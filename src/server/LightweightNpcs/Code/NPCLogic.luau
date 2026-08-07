local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local NPCHealth = require(script.Parent.NPCHealth)
local NpcTypes = require(script.Parent.NpcTypes)
local MathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)
local NPC_CULL_DISTANCE = 400
local NpcStateModule = require(game.ReplicatedFirst.LightweightNpcsClient.Code.NpcState)
local NPCLogic = {}
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

local function InitializeOnSpawn(npcRecord: NpcTypes.npcRecordType)
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
				npcRecord.onLimbHit:Fire(damageInflicted, nil, nil, attacker)
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
				npcRecord:PlayAnimation("idle", false, 1, 1)
			else
				--run
				local ang = math.random() * math.pi * 2
				npcRecord:Move(MathUtils:PlayerAngleToVec(ang))
				npcRecord:PlayAnimation("walk", false, 1, 1)
			end
		end
	end)

	npcRecord.onLimbHit:Connect(
		function(damage: number, limbHit: number, shotPos: Vector3?, shotPosNormal: Vector3?, attacker: any?)
			local totalDmg = damage * LimbDamageMultiplier[limbHit]

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
			local damageType = damageData.Type
			if damageType == "Shot" then
				self:HitByGunshot(npcRecord, damageData)
			elseif damageType == "Inflict" then
				self:HitByInflictingBullet(npcRecord, damageData)
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
		end
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
