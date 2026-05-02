local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCEvents = require(ServerScriptService.Server.NPCEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local PlayerSignals = require(script.Parent.PlayerSignals)

return {
	PlayerSignals.RemovePlayerClass:Connect(function(humanoid: Humanoid?)
		assert(humanoid, "Humanoid nil when removing from player's table")
		assert(humanoid:IsA("Humanoid"), "Humanoid not humanoid type when removing from player's table")
		if humanoid.Parent and CollectionService:HasTag(humanoid.Parent, "NPC") then
			warn("NPC DESTROYED")
			NPCEvents.CurrentSpawnedNPCS -= 1

			if CollectionService:HasTag(humanoid.Parent, "Sheriff") then
				NPCEvents.SheriffsSpawned -= 1
			end
		end
		PlayerManager:RemoveHumanClass(humanoid)

		print("Player removed from player class!")
	end),
}
