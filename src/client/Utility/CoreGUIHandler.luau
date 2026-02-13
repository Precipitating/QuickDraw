local CoreGUIHandler = {}

function CoreGUIHandler.ToggleBackpackVisibility(state: boolean)
	print(`Backpack visibility state = {state}`)
	--StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, state)
end

return CoreGUIHandler
