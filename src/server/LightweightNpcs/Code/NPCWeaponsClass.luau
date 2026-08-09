local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
local ThrowablesEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.ThrowablesEnum)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local NPCWeaponsClass = {}

function NPCWeaponsClass:InitializeWeaponClass(npcRecord: LightweightNpcTypes.npcRecordType)
	local weaponClass: string? = npcRecord.npcType
	if not weaponClass then
		Utility.Warn("Cannot initialize NPC weapon class, missing data")
		return
	end

	local classData = NPCTypes[weaponClass]

	if not classData then
		Utility.Warn("Cannot initialize NPC weapon class, missing NPCType data")
		return
	end

	npcRecord.storedWeapon = GunsEnum[classData.WeaponName]
	npcRecord.storedThrowable = ThrowablesEnum[classData.ThrowableName]

	--

	local gunData = GunData[classData.WeaponName]

	if not gunData then
		Utility.Warn("Cannot initialize NPC weapon class, missing gun data")
		return
	end
end

function NPCWeaponsClass:EquipWeapon(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord then
		Utility.Warn("NPC cannot equip weapon, missing valid arguments")
		return
	end

	npcRecord.currentEquipped = npcRecord.storedWeapon
	npcRecord.onPoseChange:Fire("toolhold")
	npcRecord:AddClientEvent({ id = "EquipWeapon", weaponToEquip = npcRecord.currentEquipped })
end
function NPCWeaponsClass:ReloadWeapon(npcRecord: LightweightNpcTypes.npcRecordType) end

function NPCWeaponsClass:UnequipAll(npcRecord: LightweightNpcTypes.npcRecordType)
	npcRecord.currentEquipped = nil
	npcRecord:AddClientEvent({ id = "UnEquipAll" })
end

return NPCWeaponsClass
