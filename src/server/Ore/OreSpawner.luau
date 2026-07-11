local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local OreData = require(script.Parent.OreData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local OreSpawner = {}
local OrePoints = ServerStorage.OreSpawnSweepPoints:GetChildren()
local OreTable = OreData
local SpawnDelay = 300
local MaxSpawnNumber = 20
local SpawnerLoop = true

function OreSpawner:GetRandomOre()
	local chosenOreInstance = nil

	-- gets table's value
	chosenOreInstance = RandomModule.WeightedRandom(OreData)

	return chosenOreInstance
end

local function InitializeOreTable()
	for key, table in OreTable do
		local weight = table.weight
		local worth = table.worth

		-- Ensure all the ores data keys exist
		if not weight or not worth then
			warn("Check OreData, missing a key")
			return
		end

		-- ensure ores folder exists in ServerStorage
		local oresFolder = ServerStorage:FindFirstChild("Ores")
		if not oresFolder then
			warn("Missing ores folder in serverstorage?")
			return
		end

		-- get ore instance
		local oreInstance = oresFolder:FindFirstChild(key)

		if not oreInstance then
			warn(`{key} instance doesn't exist in Ores folder (serverstorage)`)
			continue
		end

		-- assign instance to table's value
		table.value = oreInstance
	end
end

local function GetOreSpawnPoint(chosenAttachment: Attachment?)
	if not chosenAttachment then
		warn("Ore spawn attachment not specified")
		return
	end

	local origin = chosenAttachment.WorldPosition
	local radius = 10
	local rayLength = 50
	local attempts = 20

	for _ = 1, attempts do
		local angle = RandomModule.GetRandom() * math.pi * 2

		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))

		local rayOrigin = origin + direction * radius

		-- Ray points inward toward the attachment
		local result = workspace:Raycast(rayOrigin, -direction * rayLength)

		if result then
			if not result.Instance or not result.Instance:IsA("Terrain") then
				return nil
			end
			return result.Position, result.Normal
		end
	end

	return nil
end

function OreSpawner:CanSpawn()
	local spawnedOres = Utility.GetInstance(workspace, false, "CaveTown", "SpawnedOres")
	if not spawnedOres then
		return false
	end

	local spawnedCount = #spawnedOres:GetChildren()

	if not spawnedCount then
		return false
	end
	if spawnedCount >= MaxSpawnNumber then
		return false
	end

	return true
end

function OreSpawner:Initialize()
	InitializeOreTable()
	while SpawnerLoop and task.wait(SpawnDelay) do
		if not self:CanSpawn() then
			continue
		end
		-- Note that theres an extra key used called worth, WeightRandom only touches weight & value so it works fine
		local chosenOre = self:GetRandomOre()
		local chosenPoint = OrePoints[RandomModule.GetRandomIntBetween(1, #OrePoints)]
		local spawnPos, _ = GetOreSpawnPoint(chosenPoint)

		if not spawnPos then
			continue
		end

		chosenOre = chosenOre:Clone()
		chosenOre:PivotTo(CFrame.new(spawnPos))
		chosenOre.Parent = Utility.GetInstance(workspace, false, "CaveTown", "SpawnedOres")
	end
end

return OreSpawner
