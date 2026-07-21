local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Animal = require(script.Parent.Animal)
local Buffalo = require(script.Parent.Buffalo)
local AnimalHandler = {}
local SpawnLoop = true
local AnimalLimit = 10
local ActiveAnimalsCount = 0
local AnimalsFolder = ServerStorage.NPCs.Animals.Models:GetChildren()
local AnimalSpawns = ServerStorage.NPCs.Animals.SpawnAreas:GetChildren()
local AnimalDelay = 10
local ActiveAnimals = {}

function AnimalHandler:GetAnimal(key: Humanoid)
	if not key then
		return
	end

	return ActiveAnimals[key]
end

function AnimalHandler:StartSpawnLoop()
	while SpawnLoop and task.wait(AnimalDelay) do
		if ActiveAnimalsCount >= AnimalLimit then
			continue
		end

		local animal = AnimalsFolder[RandomModule.GetRandomIntBetween(1, #AnimalsFolder)]:Clone()
		local pos = AnimalSpawns[RandomModule.GetRandomIntBetween(1, #AnimalSpawns)]
		animal:PivotTo(CFrame.new(pos.WorldPosition))
		animal.Parent = workspace.NPCs
	end
end
function AnimalHandler:Initialize()
	--	local existingAnimals = CollectionService:GetTagged("Animal")

	-- for key, model in existingAnimals do
	-- 	local humanoid = model:FindFirstChild("Humanoid")

	-- 	if humanoid then
	-- 		local animalType = model:GetAttribute("Type")
	-- 		if animalType == "Buffalo" then
	-- 			ActiveAnimals[humanoid] = Buffalo.new(model, "Buffalo")
	-- 			warn(`Buffalo class initialized for {model.Name}`)
	-- 		else
	-- 			ActiveAnimals[humanoid] = Animal.new(model, animalType)
	-- 			warn(`Animal class initialized for {model.Name}`)
	-- 		end
	-- 		ActiveAnimalsCount = math.max(0, ActiveAnimalsCount + 1)

	-- 	end
	-- end

	CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(animalModel)
		local humanoid = animalModel:FindFirstChild("Humanoid")

		if humanoid and not ActiveAnimals[humanoid] then
			local animalType = animalModel:GetAttribute("Type")

			if animalType == "Buffalo" then
				ActiveAnimals[humanoid] = Buffalo.new(animalModel, "Buffalo")
				warn(`Buffalo class initialized for {animalModel.Name}`)
			else
				ActiveAnimals[humanoid] = Animal.new(animalModel, animalType)
				warn(`Animal class initialized for {animalModel.Name}`)
			end
			ActiveAnimalsCount = math.max(0, ActiveAnimalsCount + 1)
			animalModel.Name = `{animalModel.Name}{ActiveAnimalsCount}`
		end
	end)

	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(function(animalModel)
		local humanoid = animalModel:FindFirstChild("Humanoid")
		warn(`Animal class removed: {animalModel.Name}`)
		if humanoid then
			ActiveAnimals[humanoid]:Destroy()
			ActiveAnimals[humanoid] = nil
			warn(`Animal class destroyed for {animalModel.Name}`)
			ActiveAnimalsCount = math.max(0, ActiveAnimalsCount - 1)
		end
	end)

	self:StartSpawnLoop()
end

return AnimalHandler
