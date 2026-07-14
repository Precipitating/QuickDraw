local CollectionService = game:GetService("CollectionService")
local Animal = require(script.Parent.Animal)
local AnimalHandler = {}

local ActiveAnimals = {}

function AnimalHandler:Initialize()
	local existingAnimals = CollectionService:GetTagged("Animal")

	for key, model in existingAnimals do
		local humanoid = model:FindFirstChild("Humanoid")

		if humanoid then
			ActiveAnimals[humanoid] = Animal.new(model, model:GetAttribute("Type"))
			warn(`Animal class initialized for {model.Name}`)
		end
	end

	CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(animalModel)
		local humanoid = animalModel:FindFirstChild("Humanoid")

		if humanoid then
			ActiveAnimals[humanoid] = Animal.new(animalModel, animalModel:GetAttribute("Type"))
			warn(`Animal class initialized for {animalModel.Name}`)
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
