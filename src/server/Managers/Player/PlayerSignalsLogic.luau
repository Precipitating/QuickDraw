local PlayerManager = require(script.Parent.PlayerManager)
local PlayerSignals = require(script.Parent.PlayerSignals)

return {
	PlayerSignals.RemovePlayerClass:Connect(function(humanoid: Humanoid?)
		assert(humanoid, "Humanoid nil when removing from player's table")
		assert(humanoid:IsA("Humanoid"), "Humanoid not humanoid type when removing from player's table")

		PlayerManager:RemoveHumanClass(humanoid)

		print("Player removed from player class!")
	end),
}
