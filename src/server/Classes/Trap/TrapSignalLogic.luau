local ServerTrapNetwork = require(script.Parent.ServerTrapNetwork)
local TrapSignals = require(script.Parent.TrapSignals)

return {
	TrapSignals.ConnectTrapSignal:Connect(function(player: Player, trap: Tool)
		print("Throwable connect signal fired!")
		ServerTrapNetwork.networker:fire(player, "ConnectTrap", trap)
	end),
}
