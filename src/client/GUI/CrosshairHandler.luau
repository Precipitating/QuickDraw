local UserInputService = game:GetService("UserInputService")

local CrosshairHandler = {}
local CrosshairIDs = {
	["Gun"] = "http://www.roblox.com/asset/?id=117431027",
}

function CrosshairHandler.ChangeCrosshair(name: string)
	assert(CrosshairIDs[name], "This crosshair name doesn't exist in table to change!")

	UserInputService.MouseIcon = CrosshairIDs[name]
end

function CrosshairHandler:ToggleCrosshairVisibility(active: boolean, crosshairName: string?)
	UserInputService.MouseIconEnabled = active

	if crosshairName then
		self.ChangeCrosshair(crosshairName)
	end
end

return CrosshairHandler
