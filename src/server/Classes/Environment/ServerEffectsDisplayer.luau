local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerEffectsDisplayer = {}

-- Send these effects down to client to emit
function ServerEffectsDisplayer:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
	self.networker:fireAll("DisplayDestroyParticle", destroyableParticleName, position)
end
function ServerEffectsDisplayer:DisplaySpreadParticle(
	destroyableParticleName: string,
	duration: number,
	parent: BasePart?
)
	self.networker:fireAll("DisplaySpreadParticle", destroyableParticleName, duration, parent)
end

function ServerEffectsDisplayer:DisplayBulletHole(cframeTarget: CFrame?)
	assert(cframeTarget, "[ServerGunHandler.DisplayBulletHole] cframeTarget is nil")
	self.networker:fireAll("DisplayBulletHole", cframeTarget)
end

function ServerEffectsDisplayer:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "[ServerGunHandler.DisplayBulletHole] position is nil")
	assert(normal, "[ServerGunHandler.DisplayBulletHole] normal is nil")
	self.networker:fireAll("DisplayBloodHit", position, normal)
end

-- Fired from client to display to other players their muzzle flash.
function ServerEffectsDisplayer:DisplayMuzzleFlashToOthers(player: Player?, gunTool: Tool?)
	if not gunTool then
		warn("[ServerGunHandler:ActivateMuzzleFlash] gun reference invalid")
		return
	end
	local shotPos = gunTool:FindFirstChild("Frame", true)
	if player and player:IsA("Player") then
		self.networker:fireAllExcept(player, "DisplayMuzzleFlash", gunTool)

		warn("OI")
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
ServerEffectsDisplayer.networker = Networker.new(
	"EffectsDisplayerNetwork",
	ServerEffectsDisplayer,
	{ ServerEffectsDisplayer.DisplayMuzzleFlashToOthers }
)
return ServerEffectsDisplayer
