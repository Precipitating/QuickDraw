local GunSignals = require(script.Parent.GunSignals)
local ServerGunHandler = require(script.Parent.ServerGunHandler)

return {
	GunSignals.ConnectGunSignal:Connect(function(player: Player, gun: Tool)
		print("Gun connect signal fired!")
		ServerGunHandler.networker:fire(player, "ConnectGun", gun)
	end),

	GunSignals.FireMuzzleFlash:Connect(function(player: Player, gunTool: Tool?)
		if not gunTool then
			warn("[GunSignals.FireMuzzleFlash] gun tool ref invalid")
			return
		end
		ServerGunHandler:ActivateMuzzleFlash(player, gunTool)
	end),
}
