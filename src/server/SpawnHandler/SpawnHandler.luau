local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local SpawnLocations = ReplicatedStorage.Shared.Templates.SpawnLocations
local SpawnHandler = {}
local CHECK_RADIUS = 30

function SpawnHandler:SpawnPlayer(player: Player, loadCharacter: boolean?)
	if loadCharacter then
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)

		if not ok then
			error(err)
		end
	end

	local characterModel = player.Character
	if not characterModel then
		warn("Can't teleport player to spawn, missing model")
		return
	end

	local safeLocations = {}
	local spawnLocations = SpawnLocations:GetChildren()

	for _, spawn in spawnLocations do
		local partsNearSpawn = workspace:GetPartBoundsInRadius(spawn.Position, CHECK_RADIUS)
		local occupied = false

		for _, part in partsNearSpawn do
			if not part:IsA("MeshPart") then
				continue
			end
			if part.Parent and CollectionService:HasTag(part.Parent, "Player") then
				if not CollectionService:HasTag(part, "Dead") and not CollectionService:HasTag(part.Parent, "Dead") then
					warn(`Player found on {spawn.Name}, ignoring.`)
					occupied = true
					break
				end
			end
		end

		if not occupied then
			table.insert(safeLocations, spawn)
		end
	end

	if #safeLocations <= 0 then
		warn("All spawns occupied, falling back to random spawn")
		characterModel:PivotTo(spawnLocations[math.random(1, #spawnLocations)].CFrame)
		return
	end

	characterModel:PivotTo(safeLocations[RandomModule.GetRandomIntBetween(1, #safeLocations)].CFrame)
end

return SpawnHandler
