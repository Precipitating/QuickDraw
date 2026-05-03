local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCEvents = require(ServerScriptService.Server.NPCEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local PlayerSignals = require(script.Parent.PlayerSignals)

return {
	PlayerSignals.RemovePlayerClass:Connect(function(humanoid: Humanoid?)
		assert(humanoid, "Humanoid nil when removing from player's table")
		assert(humanoid:IsA("Humanoid"), "Humanoid not humanoid type when removing from player's table")

		PlayerManager:RemoveHumanClass(humanoid)

		if humanoid.Parent and CollectionService:HasTag(humanoid.Parent, "NPC") then
			warn("NPC DESTROYED")
			NPCEvents.CurrentSpawnedNPCS -= 1

			for key, _ in NPCEvents.NPCTypesSpawned do
				if CollectionService:HasTag(humanoid.Parent, key) then
					NPCEvents.NPCTypesSpawned[key] = math.max(0, NPCEvents.NPCTypesSpawned[key] - 1)
					break
				end
			end
		end

		print(`Human class removed`)
	end),
}
