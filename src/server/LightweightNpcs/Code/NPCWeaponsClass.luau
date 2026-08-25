local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
local ThrowablesEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.ThrowablesEnum)
local ProjectileContext = require(script.Parent.Parent.Parent.ProjectilesHandler.ProjectileContext)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local WeaponsFolder = ReplicatedStorage.Shared.Templates
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

function NPCWeaponsClass:SingleShot(agent, targetPosition: Vector3)
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

	local dir = (targetPosition - agent.data.shootPoint.Position).Unit
	local appliedSpreadDir = Utility.GetSingleShotSpreadDir(dir, RandomModule.GetRandomIntBetween(0, 15))

	GunRaycastParam.ExcludeInstances = { agent.serverRig }

	context = ProjectileContext.BulletContext.new({
		Origin = agent.data.shootPoint.Position,
		Direction = appliedSpreadDir,
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

function NPCWeaponsClass:SpreadShot(agent, targetPosition: Vector3)
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
	GunRaycastParam.ExcludeInstances = { agent.serverRig }

	for _ = 1, pelletCount do
		local dirToTarget = (targetPosition - agent.data.shootPoint.Position).Unit
		local spreadDir = Utility.GetShotgunSpreadDirection(dirToTarget, maxSpreadAngle)
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

function NPCWeaponsClass:GetLocalMuzzleOffset(npcRecord: LightweightNpcTypes.npcRecordType)
	local weaponId = npcRecord.currentEquipped
	if not weaponId then
		Utility.Warn(`[NPCWeaponsClass:GetLocalMuzzleOffset] Missing weapon id`)
		return
	end
	local weaponTool = WeaponsFolder:FindFirstChild(GunsEnum[weaponId])

	if not weaponTool then
		return
	end

	local muzzle: Attachment? = weaponTool:FindFirstChild("ShootPoint")
		or weaponTool:FindFirstChildOfClass("Attachment")

	if not muzzle then
		Utility.Warn(`[NPCWeaponsClass:GetLocalMuzzleOffset] Missing ShootPoint attachment`)
		return
	end

	local handle = weaponTool:FindFirstChild("Handle")

	if not handle then
		Utility.Warn(`[NPCWeaponsClass:GetLocalMuzzleOffset] Missing handle`)
		return
	end

	npcRecord.data.muzzleOffset = handle.CFrame:ToObjectSpace(muzzle.WorldCFrame)
end

function NPCWeaponsClass:EquipWeapon(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord then
		Utility.Warn("NPC cannot equip weapon, missing valid arguments")
		return
	end

	npcRecord.currentEquipped = npcRecord.storedWeapon
	npcRecord.currentEquippedData = GunData[GunsEnum[npcRecord.currentEquipped]]
		or ThrowableData[ThrowablesEnum[npcRecord.currentEquipped]]
	self:GetLocalMuzzleOffset(npcRecord)
	npcRecord.currentWeaponAmmo = npcRecord.currentEquippedData.MaxAmmo

	-- NOTE: This just attaches the weapon to the NPC on client, its anchored so using humanoid equiped doesn't work.
	npcRecord:AddClientEvent({ id = "EquipWeapon", weaponToEquip = npcRecord.currentEquipped })
end
function NPCWeaponsClass:ReloadWeapon(npcRecord: LightweightNpcTypes.npcRecordType)
	local gunData = npcRecord.currentEquippedData
	if not gunData then
		Utility.Warn(`Cannot reload, missing gun data`)
		return
	end

	local perBulletReload = gunData.ReloadTimePerBullet
	local reloadSound = gunData.ReloadSoundName
	local reloadSoundStart = gunData.ReloadSoundStartName
	local magazineReload = gunData.ReloadTime
	local maxAmmo = gunData.MaxAmmo

	if reloadSoundStart then
		ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSoundStart, npcRecord.position)
	end

	if perBulletReload then
		for _ = 1, maxAmmo do
			local currentState = npcRecord.ai.currentGoal.name
			if currentState ~= "Reload" then
				return
			end
			if reloadSoundStart then
				ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSound, npcRecord.position)
			end

			npcRecord.currentWeaponAmmo = math.clamp(npcRecord.currentWeaponAmmo + 1, 0, maxAmmo)
		end
	else
		task.delay(magazineReload, function()
			local currentState = npcRecord.ai.currentGoal.name
			if currentState ~= "Reload" then
				return
			end

			npcRecord.currentWeaponAmmo = maxAmmo
		end)
	end
end

function NPCWeaponsClass:UnequipAll(npcRecord: LightweightNpcTypes.npcRecordType)
	npcRecord.currentEquipped = nil
	npcRecord:StopAnimationChannel(2)
	npcRecord:AddClientEvent({ id = "UnEquipAll" })
end

return NPCWeaponsClass
