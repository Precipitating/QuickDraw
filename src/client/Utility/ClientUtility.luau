local LocalPlayer = game:GetService("Players").LocalPlayer
local PlayerModule = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
local Controls = require(PlayerModule):GetControls()
local ClientUtility = {}

function ClientUtility.ToggleControls(manualSet: boolean)
	if manualSet ~= nil then
		if manualSet == true then
			Controls:Enable()
			print("Controls enabled")
		else
			Controls:Disable()
			print("Controls disabled")
		end
	end
end

return ClientUtility
