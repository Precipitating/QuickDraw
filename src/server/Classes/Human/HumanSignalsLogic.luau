local ServerScriptService = game:GetService("ServerScriptService")
local StaminaBarGUI = require(ServerScriptService.Server.GUI.StaminaBarGUI)
local HumanSignals = require(script.Parent.HumanSignals)

return {
	HumanSignals.ConnectHumanGUIs:Connect(function(player: Player, humanoid: Humanoid)
		StaminaBarGUI:Connect(player, humanoid)
	end),
}
