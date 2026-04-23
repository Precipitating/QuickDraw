local LocalPlayer = game:GetService("Players").LocalPlayer
local PlayerModule = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
local Controls = require(PlayerModule):GetControls()
local ClientUtility = {}

function ClientUtility.ToggleControls(manualSet: boolean)
	if manualSet ~= nil then
		if manualSet == true then
			Controls:Enable()
			warn(`[CLIENT] Controls enabled`)
		else
			Controls:Disable()
			warn(`[CLIENT] Controls disabled`)
		end
	end
end

return ClientUtility
