local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)

local Networker = require(ReplicatedStorage.Packages.Networker).client

type Networker = NetworkClient

local ClientGunHandler = {}
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)

function ClientGunHandler:ActivateMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end
	local muzzleFolder = gunTool:WaitForChild("MuzzleFlash"):WaitForChild("Attachment")

	if not muzzleFolder then
		warn("[ ClientGunHandler:ActivateMuzzleFlash] muzzleFolder invalid!")
		return
	end

	for _, effect in pairs(muzzleFolder:GetChildren()) do
		if not effect:IsA("ParticleEmitter") then
			continue
		end

		effect.Enabled = true
		task.delay(0.1, function()
			effect.Enabled = false
		end)
	end

	self:ApplyPistolRecoil(gunTool)
end
function ClientGunHandler:ApplyPistolRecoil(gunTool: Tool)
	local handle: Part? = gunTool:WaitForChild("Handle") :: Part
	local shootPoint: Attachment? = gunTool:WaitForChild("ShootPoint") :: Attachment
	local gunHolderModel: Model? = gunTool:FindFirstAncestorOfClass("Model")
	assert(gunHolderModel, "Cannot apply recoil locally, can't get person's model")

	local rightArm: MeshPart = gunHolderModel:WaitForChild("RightUpperArm", 10) :: MeshPart

	if not handle then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get Handle`)
		return
	end
	if not shootPoint then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get shootPoint`)
		return
	end
	if not rightArm then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get right upper arm`)
		return
	end

	handle:ApplyImpulseAtPosition(Vector3.new(0, 1, 0) * 10, shootPoint.WorldPosition)
	rightArm:ApplyImpulse(rightArm.AssemblyMass * Vector3.new(0, 1, 0) * 100)
end

function ClientGunHandler:ConnectGun(gun: Tool?)
	print("connectin")
	if not gun then
		error("Can't connect guns, tool reference not valid!")
	end

	gun.Activated:Connect(function()
		local shot = GunNetwork:fetch("ShootGun", PlayerContext.Humanoid)

		if shot then
			self:ActivateMuzzleFlash(gun)
		end
	end)
end

return GunNetwork
