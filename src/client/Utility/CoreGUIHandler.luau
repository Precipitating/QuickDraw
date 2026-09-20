local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local CoreGUIHandler = {}

local BackpackVisibilityLocked = false

function CoreGUIHandler.ToggleBackpackVisibility(state: boolean, locked: boolean?)
	if BackpackVisibilityLocked and locked ~= false then
		return
	end

	Utility.Warn(`[CLIENT] Backpack visibility state = {state}`)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, state)

	if locked ~= nil then
		BackpackVisibilityLocked = locked
	end
end

return CoreGUIHandler
