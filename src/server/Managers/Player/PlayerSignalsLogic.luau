local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerManager = require(script.Parent.PlayerManager)
local PlayerSignals = require(script.Parent.PlayerSignals)
local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	PlayerSignals.RemovePlayerClass:Connect(function(humanoid: Humanoid?)
		assert(humanoid, "Humanoid nil when removing from player's table")
		assert(humanoid:IsA("Humanoid"), "Humanoid not humanoid type when removing from player's table")

		PlayerManager:RemoveHumanClass(humanoid)
	end),
}
