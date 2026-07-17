local CollectionService = game:GetService("CollectionService")
local Animal = require(script.Parent.Animal)
local Buffalo = require(script.Parent.Buffalo)
local AnimalHandler = {}

local ActiveAnimals = {}

function AnimalHandler:GetAnimal(key: Humanoid)
	if not key then
		return
	end

	return ActiveAnimals[key]
end

function AnimalHandler:Initialize()
	local existingAnimals = CollectionService:GetTagged("Animal")

	for key, model in existingAnimals do
		local humanoid = model:FindFirstChild("Humanoid")

		if humanoid then
			local animalType = model:GetAttribute("Type")
			if animalType == "Buffalo" then
				ActiveAnimals[humanoid] = Buffalo.new(model, "Buffalo")
				warn(`Buffalo class initialized for {model.Name}`)
			else
				ActiveAnimals[humanoid] = Animal.new(model, animalType)
				warn(`Animal class initialized for {model.Name}`)
			end
		end
	end

	CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(animalModel)
		local humanoid = animalModel:FindFirstChild("Humanoid")

		if humanoid then
			local animalType = animalModel:GetAttribute("Type")

			if animalType == "Buffalo" then
				ActiveAnimals[humanoid] = Buffalo.new(animalModel, "Buffalo")
				warn(`Buffalo class initialized for {animalModel.Name}`)
			else
				ActiveAnimals[humanoid] = Animal.new(animalModel, animalType)
				warn(`Animal class initialized for {animalModel.Name}`)
			end
		end
	end)

	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(function(animalModel)
		local humanoid = animalModel:FindFirstChild("Humanoid")

		if humanoid then
			ActiveAnimals[humanoid]:Destroy()
			ActiveAnimals[humanoid] = nil
			warn(`Animal class destroyed for {animalModel.Name}`)
		end
	end)
end

return AnimalHandler
