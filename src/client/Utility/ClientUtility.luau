local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LocalPlayer = game:GetService("Players").LocalPlayer
local PlayerModule = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
local Controls = require(PlayerModule):GetControls()
local ClientUtility = {}

function ClientUtility.ToggleControls(manualSet: boolean)
	if manualSet ~= nil then
		if manualSet == true then
			Controls:Enable()
			Utility.Warn(`[CLIENT] Controls enabled`)
		else
			Controls:Disable()
			Utility.Warn(`[CLIENT] Controls disabled`)
		end
	end
end

return ClientUtility
