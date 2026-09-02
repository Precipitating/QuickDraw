local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightweightNpcTypes = require(script.Parent.LightweightNpcTypes)

local NpcStateModule = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
local Zone = require(ReplicatedStorage.Shared.QuickZone.Classes.Zone)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local NPCPhysics = {}

function NPCPhysics:ToggleNPCCollision(npcRecord: LightweightNpcTypes.npcRecordType, enabled: boolean)
	if not npcRecord or not npcRecord.serverRig then
		Utility.Warn(`[ToggleNPCCollision] Missing NPC instance or record`)
		return
	end

	for _, part in npcRecord.serverRig:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end

		part.CollisionGroup = if enabled then "Ragdoll" else "NPC"
	end
end

function NPCPhysics:Ragdoll(npcRecord: LightweightNpcTypes.npcRecordType, duration: number?, onChanged: (() -> ())?)
	if npcRecord.npcState == NpcStateModule.Dying or npcRecord.npcState == NpcStateModule.Ragdolled then
		return
	end

	npcRecord.npcState = NpcStateModule.Ragdolled

	npcRecord:AddClientEvent({ id = "Ragdoll", duration = duration })
	self:ToggleNPCCollision(npcRecord, true)

	if onChanged then
		onChanged()
	end
	-- Reset if duration
	if duration then
		task.delay(duration, function()
			if npcRecord.npcState == NpcStateModule.Dying or npcRecord.hitPoints <= 0 then
				return
			end
			npcRecord.npcState = NpcStateModule.Running
			self:ToggleNPCCollision(npcRecord, false)
		end)
	end
end

function NPCPhysics:ApplyImpulse(npcRecord: LightweightNpcTypes.npcRecordType, impulse: Vector3?)
	if not npcRecord.instance then
		return
	end
	if not impulse then
		Utility.Warn(`[ NPCPhysics:ApplyImpulse] Missing impulse`)
		return
	end

	if npcRecord.npcState == NpcStateModule.Ragdolled or npcRecord.npcState == NpcStateModule.Dying then
		return
	end

	npcRecord:Move(Vector3.zero)
	npcRecord.velocity = Vector3.zero

	npcRecord.knockbackVelocity = (npcRecord.knockbackVelocity or Vector3.zero) + impulse
end

return NPCPhysics
