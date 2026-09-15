local ToolNetwork = require(script.Parent.Parent.Tools.ToolNetwork)
local ToolSignals = require(script.Parent.ToolSignals)

return {
	ToolSignals.ConnectTrapSignal:Connect(function(player: Player, trap: Tool)
		print("Trap connect signal fired!")
		ToolNetwork.networker:fire(player, "ConnectTrap", trap)
	end),
	ToolSignals.ConnectHealItemSignal:Connect(function(player: Player, tool: Tool)
		print("Heal item connect signal fired!")
		ToolNetwork.networker:fire(player, "ConnectHealTool", tool)
	end),
}
