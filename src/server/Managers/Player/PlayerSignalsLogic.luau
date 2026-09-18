local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
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
				local parent = humanoid.Parent
				if not parent then
					continue
				end
				if CollectionService:HasTag(parent, key) then
					NPCEvents.NPCTypesSpawned[parent][key] = math.max(0, NPCEvents.NPCTypesSpawned[parent][key] - 1)
					break
				end
			end
		end

		print(`Human class removed`)
	end),

	PlayerSignals.ReduceNPCCounter:Connect(function(npcModel: Model, npcFaction: string)
		if not npcFaction then
			return
		end
		local npcLocation = npcModel:GetAttribute("Location")
		if not npcLocation then
			Utility.Warn(`NPC missing location attribute to reduce NPC counter`)
			return
		end

		for key, _ in NPCEvents.NPCTypesSpawned[npcLocation] do
			if npcModel:HasTag(key) then
				NPCEvents.NPCTypesSpawned[npcLocation][key] =
					math.max(0, NPCEvents.NPCTypesSpawned[npcLocation][key] - 1)
				break
			end
		end
		Utility.Warn(`NPC counter reduced -1 from location {npcLocation}`)
	end),
}
