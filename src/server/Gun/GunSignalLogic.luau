local GunSignals = require(script.Parent.GunSignals)
local ServerGunHandler = require(script.Parent.ServerGunHandler)

return {
	GunSignals.ConnectGunSignal:Connect(function(player: Player, gun: Tool)
		print("Gun connect signal fired!")
		ServerGunHandler.networker:fire(player, "ConnectGun", gun)
	end),

	GunSignals.FireMuzzleFlash:Connect(function(player: Player, muzzleFolder: Attachment?)
		if not muzzleFolder then
			warn("[GunSignals.FireMuzzleFlash] Muzzle folder ref invalid")
			return
		end
		ServerGunHandler:ActivateMuzzleFlash(player, muzzleFolder)
	end),
}
