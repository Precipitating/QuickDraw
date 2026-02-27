local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
return {
	ConnectHumanGUIs = Signal.new(),
	RagdollClient = Signal.new(),
	AdjustGrayscale = Signal.new(),
}
