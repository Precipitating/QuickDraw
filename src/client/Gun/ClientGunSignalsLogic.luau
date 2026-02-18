local ClientGunHandler = require(script.Parent.ClientGunHandler)
local ClientGunSignals = require(script.Parent.ClientGunSignals)
return {

	ClientGunSignals.DisconnectGun:Connect(function()
		ClientGunHandler:DisconnectGun()
	end),
}
