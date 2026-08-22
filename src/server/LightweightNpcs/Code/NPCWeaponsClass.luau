local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
local ThrowablesEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.ThrowablesEnum)
local ProjectileContext = require(script.Parent.Parent.Parent.ProjectilesHandler.ProjectileContext)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local GunRaycastParam = RaycastParams.new()
GunRaycastParam.CollisionGroup = "Projectile"

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

function NPCWeaponsClass:SingleShot(agent)
	local gunData = agent.currentEquippedData
	local projectileData = agent.currentEquippedData.ProjectileData
	local context = nil
	if not projectileData then
		warn("Projectile data invalid, can't shoot")
		return
	end

	if not ProjectileContext.Solver then
		warn("ProjectileContext Solver reference missing in Gun class")
		return
	end

	context = ProjectileContext.BulletContext.new({
		Origin = agent.data.shootPoint.Position,
		Direction = agent.data.shootPoint.LookVector,
		Speed = gunData.Velocity,
		RaycastParams = GunRaycastParam,
	})

	context.UserData.Owner = agent.instance
	context.UserData.Damage = gunData.Damage
	context.UserData.ProjectileType = "Bullet"
	context.UserData.GunType = gunData.GunType

	if not context then
		warn("Singleshot context is invalid")
		return
	end

	ProjectileContext.Solver:Fire(context, projectileData)
	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		gunData.ShootSoundName,
		agent.hrp.Position,
		{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
	)
end

function NPCWeaponsClass:SpreadShot(agent)
	local gunData = agent.currentEquippedData
	local gunName = gunData.Name
	local pelletCount = gunData.PelletsPerShot
	local maxSpreadAngle = gunData.MaxSpreadAngle
	local projectileData = gunData.ProjectileData

	if not projectileData then
		warn("Vetra projectile data is missing!")
		return
	end
	if not pelletCount then
		warn(`Pellet count not specified for {gunName}`)
		return
	end

	for _ = 1, pelletCount do
		local spreadDir = Utility.GetShotgunSpreadDirection(agent.data.shootPoint.WorldAxis, maxSpreadAngle)
		local context = ProjectileContext.BulletContext.new({
			Origin = agent.data.shootPoint.Position,
			Direction = spreadDir,
			Speed = gunData.Velocity,
			RaycastParams = GunRaycastParam,
		})

		context.UserData.Owner = agent.instance
		context.UserData.Damage = gunData.Damage
		context.UserData.ProjectileType = "Bullet"
		context.UserData.GunType = gunData.GunType

		ProjectileContext.Solver:Fire(context, projectileData)
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			gunData.ShootSoundName,
			agent.hrp.Position,
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
		)
	end
end

function NPCWeaponsClass:EquipWeapon(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord then
		Utility.Warn("NPC cannot equip weapon, missing valid arguments")
		return
	end

	npcRecord.currentEquipped = npcRecord.storedWeapon
	npcRecord.currentEquippedData = GunData[GunsEnum[npcRecord.currentEquipped]]
		or ThrowableData[ThrowablesEnum[npcRecord.currentEquipped]]
	npcRecord.onPoseChange:Fire("toolhold")
	npcRecord:AddClientEvent({ id = "EquipWeapon", weaponToEquip = npcRecord.currentEquipped })
end
function NPCWeaponsClass:ReloadWeapon(npcRecord: LightweightNpcTypes.npcRecordType) end

function NPCWeaponsClass:UnequipAll(npcRecord: LightweightNpcTypes.npcRecordType)
	npcRecord.currentEquipped = nil
	npcRecord:AddClientEvent({ id = "UnEquipAll" })
end

return NPCWeaponsClass
