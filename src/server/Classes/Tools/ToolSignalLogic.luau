local ToolNetwork = require(script.Parent.Parent.Tools.ToolNetwork)
local ToolSignals = require(script.Parent.ToolSignals)

return {
	ToolSignals.ConnectTrapSignal:Connect(function(player: Player, trap: Tool)
		print("Throwable connect signal fired!")
		ToolNetwork.networker:fire(player, "ConnectTrap", trap)
	end),
}
