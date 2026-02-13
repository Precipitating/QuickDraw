local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker).client

type Networker = NetworkClient

local ClientGunHandler = {}
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)

function ClientGunHandler:ActivateMuzzleFlash(muzzleFolder: Attachment?)
	if not muzzleFolder then
		warn("Client muzzle folder NIL")
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
	print("should work")
end

function ClientGunHandler:ConnectGun(gun: Tool?)
	print("connectin")
	if not gun then
		error("Can't connect guns, tool reference not valid!")
	end

	gun.Activated:Connect(function()
		local shot = GunNetwork:fetch("ShootGun")

		if shot then
			local gunRef = gun:WaitForChild("MuzzleFlash", 5)
			local muzzleFolder: Attachment? = gunRef:WaitForChild("Attachment", 5)
			if not gunRef or not muzzleFolder then
				return
			end
			self:ActivateMuzzleFlash(muzzleFolder)
		end

		print(shot)
	end)
end

return GunNetwork
