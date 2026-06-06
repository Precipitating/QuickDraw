local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerEffectsDisplayer = {}

-- Send these effects down to client to emit
function ServerEffectsDisplayer:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
	if not destroyableParticleName or not position then
		warn(`[ServerEffectsDisplayer:DisplayDestroyParticle] one argument is nil!`)
		return
	end
	self.networker:fireAll("DisplayDestroyParticle", destroyableParticleName, position)
end
function ServerEffectsDisplayer:DisplaySpreadParticle(
	destroyableParticleName: string,
	duration: number,
	parent: BasePart?
)
	self.networker:fireAll("DisplaySpreadParticle", destroyableParticleName, duration, parent)
end

function ServerEffectsDisplayer:DisplayProjectileMark(name: string, raycastResult: RaycastResult?)
	assert(raycastResult, "[ServerGunHandler.DisplayProjectileMark] raycastResult is nil")

	-- RaycastResult does not serialize to client, so do it manually via table
	self.networker:fireAll("DisplayProjectileMark", name, {
		Position = raycastResult.Position,
		Normal = raycastResult.Normal,
		Instance = raycastResult.Instance,
		Material = raycastResult.Material,
		Distance = raycastResult.Distance,
	})
end

function ServerEffectsDisplayer:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "[ServerGunHandler.DisplayBloodHit] position is nil")
	assert(normal, "[ServerGunHandler.DisplayBloodHit] normal is nil")
	self.networker:fireAll("DisplayBloodHit", position, normal)
end

-- Fired from client to display to other players their muzzle flash.
function ServerEffectsDisplayer:DisplayMuzzleFlashToOthers(player: Player?, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
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
			shotPos:GetPivot(),
			{ Pitch = 1 + (math.random() - 0.5) * 0.1 }
		)
	end
end

function ServerEffectsDisplayer:DisplayMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	local shotPos = gunTool:FindFirstChild("Frame", true)
	if not shotPos then
		warn("[ServerGunHandler:ActivateMuzzleFlash] Missing gun frame reference ")
		return
	end

	-- its an NPC, so fire all
	self.networker:fireAll("DisplayMuzzleFlash", gunTool)
	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		GunData[gunTool.Name].ShootSoundName,
		shotPos:GetPivot(),
		{ Pitch = 1 + (math.random() - 0.5) * 0.1, MaxDistance = 300 }
	)

	print(`Server -> Client Muzzle Flash`)
end

function ServerEffectsDisplayer:DisplayImpactParticle(particle: ParticleEmitter?, position: Vector3?)
	if not particle or not position then
		return
	end

	self.networker:fireAll("DisplayImpactParticle", particle, position)
end
ServerEffectsDisplayer.networker = Networker.new(
	"EffectsDisplayerNetwork",
	ServerEffectsDisplayer,
	{ ServerEffectsDisplayer.DisplayMuzzleFlashToOthers }
)
return ServerEffectsDisplayer
