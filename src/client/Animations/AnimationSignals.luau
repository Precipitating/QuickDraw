local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
return {
	ChangeAnimationFolder = Signal.new(),
	ResetToDefaultAnimations = Signal.new(),
}
