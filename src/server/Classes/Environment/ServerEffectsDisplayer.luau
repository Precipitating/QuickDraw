local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerEffectsDisplayer = {}

local EffectsLimiter = RateLimiter.new(10)

-- Send these effects down to client to emit
function ServerEffectsDisplayer:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
	if not destroyableParticleName or not position then
		warn(`[ServerEffectsDisplayer:DisplayDestroyParticle] one argument is nil!`)
		return
	end

	if not EffectsLimiter:TryConsume() then
		return
	end

	local serializedBuf = Sera.Serialize(
		SeraSchemas.DisplayDestroySchema,
		{ DestroyableParticleName = destroyableParticleName, Position = position }
	)

	local closePlayers = Utility.GetClosePlayers(position, 100)
	self.networker:fire(closePlayers, "DisplayDestroyParticle", serializedBuf)
end
function ServerEffectsDisplayer:DisplaySpreadParticle(
	destroyableParticleName: string,
	duration: number?,
	parent: BasePart?
)
	if not EffectsLimiter:TryConsume() then
		return
	end
	local serializedBuf = Sera.Serialize(
		SeraSchemas.DisplaySpreadParticleSchema,
		{ DestroyableParticleName = destroyableParticleName, Duration = duration }
	)
	self.networker:fireAll("DisplaySpreadParticle", serializedBuf, parent)
end

function ServerEffectsDisplayer:DisplayProjectileMark(name: string, raycastResult: RaycastResult?)
	assert(raycastResult, "[ServerGunHandler.DisplayProjectileMark] raycastResult is nil")
	if not EffectsLimiter:TryConsume() then
		return
	end
	local closePlayers = Utility.GetClosePlayers(raycastResult.Position, 100)
	local serializedBuf, err = Sera.Serialize(SeraSchemas.DisplayProjectileMarkSchema, {
		Name = name,
		Position = raycastResult.Position,
		Normal = raycastResult.Normal,
	})

	if not serializedBuf then
		warn(err)
		return
	end
	-- RaycastResult does not serialize to client, so do it manually via table
	self.networker:fire(closePlayers, "DisplayProjectileMarkFromServer", serializedBuf, raycastResult.Instance)
end

function ServerEffectsDisplayer:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "[ServerGunHandler.DisplayBloodHit] position is nil")
	assert(normal, "[ServerGunHandler.DisplayBloodHit] normal is nil")
	if not EffectsLimiter:TryConsume() then
		return
	end
	local closePlayers = Utility.GetClosePlayers(position, 100)

	local serializedBuf, err = Sera.Serialize(SeraSchemas.DisplayBloodHitSchema, {
		Position = position,
		Normal = normal,
	})

	if not serializedBuf then
		warn(err)
		return
	end
	self.networker:fire(closePlayers, "DisplayBloodHitFromServer", serializedBuf)
end

-- Fired from client to display to other players their muzzle flash.
function ServerEffectsDisplayer:DisplayMuzzleFlashToOthers(player: Player?, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	if not EffectsLimiter:TryConsume() then
		return
	end

	local shotPos = gunTool:FindFirstChild("Frame", true)
	if not shotPos then
		return
	end

	if player and player:IsA("Player") then
		self.networker:fireAllExcept(player, "DisplayMuzzleFlash", gunTool)

		ServerSoundHandler:Play3DOneShotToOthers(
			player,
			GunData[gunTool.Name].ShootSoundName,
			shotPos:GetPivot().Position,
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
		)
	end
end

-- Second parameter is used for compatibility with turrets, as they dont use tools
function ServerEffectsDisplayer:DisplayMuzzleFlash(gun: Tool? | Model?, gunName: string?)
	if not gun then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	local shotPos = gun:FindFirstChild("Frame", true) or gun
	if not shotPos then
		warn("[ServerGunHandler:ActivateMuzzleFlash] Missing gun frame reference ")
		return
	end

	if not EffectsLimiter:TryConsume() then
		return
	end
	local gunData = GunData[gunName or gun.Name]

	-- its an NPC, so fire all
	self.networker:fireAll("DisplayMuzzleFlash", gun)
	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		gunData.ShootSoundName,
		shotPos:GetPivot().Position,
		{ Pitch = 1 + (math.random() - 0.5) * 0.1, MaxDistance = 300 }
	)

	print(`Server -> Client Muzzle Flash`)
end

function ServerEffectsDisplayer:DisplayImpactParticle(particle: ParticleEmitter?, position: Vector3?)
	if not particle or not position then
		return
	end
	if not EffectsLimiter:TryConsume() then
		return
	end
	local closePlayers = Utility.GetClosePlayers(position, 100)

	self.networker:fire(closePlayers, "DisplayImpactParticle", particle, position)
end
ServerEffectsDisplayer.networker = Networker.new(
	"EffectsDisplayerNetwork",
	ServerEffectsDisplayer,
	{ ServerEffectsDisplayer.DisplayMuzzleFlashToOthers }
)
return ServerEffectsDisplayer
