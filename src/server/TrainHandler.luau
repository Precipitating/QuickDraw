local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrainHandler = {}
local TrainPaths = ReplicatedStorage.Shared.Paths.TrainPaths
local Active = false

function TrainHandler:Run(active: boolean)
	Active = active

	if Active then
		task.spawn(function()
			for _, path in TrainPaths do
			end
		end)
	end
end

function TrainHandler:Initialize() end

return TrainHandler
