local ThrowableHandler = require(script.Parent.ThrowableHandler)
local ThrowableSignals = require(script.Parent.ThrowableSignals)

return {
	ThrowableSignals.ConnectThrowableSignal:Connect(function(player: Player, throwable: Tool)
		print("Throwable connect signal fired!")
		ThrowableHandler.networker:fire(player, "ConnectThrowable", throwable)
	end),
}
