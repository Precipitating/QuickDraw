local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local ThrowablesEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.ThrowablesEnum)
local ProjectileContext = require(script.Parent.Parent.Parent.ProjectilesHandler.ProjectileContext)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local WeaponsFolder = ReplicatedStorage.Shared.Templates
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local GunRaycastParam = RaycastParams.new()
GunRaycastParam.CollisionGroup = "Projectile"
local ThrowableRaycastParam = RaycastParams.new()
ThrowableRaycastParam.CollisionGroup = "Throwable"

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

function NPCWeaponsClass:SingleShot(agent: LightweightNpcTypes.npcRecordType, targetPosition: Vector3)
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

	context.UserData.Owner = agent.serverRig
	context.UserData.Damage = gunData.Damage
	context.UserData.ProjectileType = "Bullet"
	context.UserData.GunType = gunData.GunType

	if not context then
		warn("Singleshot context is invalid")
		return
	end

	ProjectileContext.Solver:Fire(context, projectileData)
	self:UpdateAmmo(agent, -1)

	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		gunData.ShootSoundName,
		agent.hrp.Position,
		{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
	)
end

function NPCWeaponsClass:UpdateAmmo(agent: LightweightNpcTypes.npcRecordType, value: number)
	if not agent.currentEquipped or not agent.currentEquippedData then
		Utility.Warn(`Cannot update ammo, NPC has no weapon equipped or weapon data`)
		return
	end
	local maxAmmo = agent.currentEquippedData.MaxAmmo
	agent.currentWeaponAmmo = math.clamp(agent.currentWeaponAmmo + value, 0, maxAmmo)
	local currentAmmo = agent.currentWeaponAmmo
	if currentAmmo <= 0 then
		agent.ai.worldState:set("canShoot", false)
	elseif currentAmmo >= maxAmmo then
		agent.ai.worldState:set("canShoot", true)
	end
end

function NPCWeaponsClass:SpreadShot(agent: LightweightNpcTypes.npcRecordType, targetPosition: Vector3)
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
	self:UpdateAmmo(agent, -1)
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

function NPCWeaponsClass:UnequipAll(npcRecord: LightweightNpcTypes.npcRecordType)
	npcRecord.currentEquipped = nil
	npcRecord:StopAnimationChannel(2)
	npcRecord:AddClientEvent({ id = "UnEquipAll" })
end

-- Get angle required for object to hit a position (if possible)
function NPCWeaponsClass:GetThrowAngle(origin, target, velocity)
	local diff = target - origin
	local horizontalDist = vector.magnitude(vector.create(diff.X, 0, diff.Z))
	local verticalDist = diff.Y
	local v2 = velocity * velocity
	local g = workspace.Gravity

	local discriminant = v2 * v2 - g * (g * horizontalDist * horizontalDist + 2 * verticalDist * v2)
	if discriminant < 0 then
		return nil, nil -- target out of range for this velocity
	end

	-- two solutions, low arc and high arc
	local lowArc = math.atan((v2 - math.sqrt(discriminant)) / (g * horizontalDist))
	local highArc = math.atan((v2 + math.sqrt(discriminant)) / (g * horizontalDist))

	return lowArc, highArc -- in radians
end

function NPCWeaponsClass:Throw(
	npcRecord: LightweightNpcTypes.npcRecordType,
	throwableData: any,
	cameraLookVector: Vector3
)
	if not throwableData then
		return false
	end

	local head = npcRecord.bodyParts[LimbsEnum.Head] and npcRecord.bodyParts[LimbsEnum.Head].Part
	if not head then
		return false
	end

	local launchPos = head.Position + vector.create(0, 2, 0)

	local context = ProjectileContext.BulletContext.new({
		Origin = launchPos,
		Direction = cameraLookVector,
		Speed = throwableData.Velocity,
		RaycastParams = ThrowableRaycastParam,
	})

	context.UserData.Class = npcRecord
	context.UserData.Owner = npcRecord.serverRig
	context.UserData.ProjectileType = "Throwable"
	context.UserData.Data = throwableData

	ProjectileContext.Solver:Fire(context, throwableData.ProjectileData)

	return true
end
function NPCWeaponsClass:ThrowThrowable(npcRecord: LightweightNpcTypes.npcRecordType, targetPos)
	local throwableData = ThrowableData[npcRecord.ai.factionData and npcRecord.ai.factionData.ThrowableName]
	if not throwableData then
		return false
	end
	-- Throw cooldown
	if npcRecord.data.lastThrown and (os.clock() - npcRecord.data.lastThrown <= throwableData.ThrowDelay) then
		return false
	end

	local origin = npcRecord.bodyParts[LimbsEnum.RightHand].Part.Position

	local lowArc, _ = self:GetThrowAngle(origin, targetPos, throwableData.Velocity)
	if not lowArc then
		return false
	end

	local toTargetDir = (targetPos - origin).Unit
	local throwDirection = (CFrame.new(Vector3.zero, toTargetDir) * CFrame.Angles(lowArc, 0, 0)).LookVector

	local thrown = self:Throw(npcRecord, throwableData, throwDirection)
	return thrown
end

return NPCWeaponsClass
