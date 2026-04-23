local StarterGui = game:GetService("StarterGui")
local CoreGUIHandler = {}

function CoreGUIHandler.ToggleBackpackVisibility(state: boolean)
	warn(`[CLIENT] Backpack visibility state = {state}`)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, state)
end

return CoreGUIHandler
