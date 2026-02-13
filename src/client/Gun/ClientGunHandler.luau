local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client

type Networker = NetworkClient

local ClientGunHandler = {}
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)

function ClientGunHandler:ConnectGun(gun: Tool?)
	print("connectin")
	if not gun then
		error("Can't connect guns, tool reference not valid!")
	end

	gun.Activated:Connect(function()
		local shot = GunNetwork:fetch("ShootGun")
		print(shot)
	end)
end

return GunNetwork
