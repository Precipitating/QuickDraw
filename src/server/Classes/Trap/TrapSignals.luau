local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	ConnectTrapSignal = Signal.new(),
}
