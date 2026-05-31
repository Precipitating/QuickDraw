local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Templates = ReplicatedStorage.Shared.Templates
local TrainPosRemote = ReplicatedStorage.Shared.Remote.TrainPositionRemote

local TrainHandler = {}

local TrainTemplate = nil
local CarriageTemplate = nil
local TargetTrainCFrame = nil
local TargetCarriageCFrame = nil
local CurrentTrainCFrame = nil
local CurrentCarriageCFrame = nil
local LERP_ALPHA = 0.3
local function DisableCollisions(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

function TrainHandler:Initialize()
	TrainTemplate = Templates:FindFirstChild("ClientTrain"):Clone()
	CarriageTemplate = Templates:FindFirstChild("ClientCarriage"):Clone()

	if not TrainTemplate or not CarriageTemplate then
		warn("Client can't spawn in train or carriage models")
		return
	end

	TrainTemplate.PrimaryPart = TrainTemplate:FindFirstChild("BASE", true)
	CarriageTemplate.PrimaryPart = CarriageTemplate:FindFirstChild("BASE", true)

	if not TrainTemplate.PrimaryPart or not CarriageTemplate.PrimaryPart then
		warn("Client train models are missing BASE part")
		return
	end

	DisableCollisions(TrainTemplate)
	DisableCollisions(CarriageTemplate)

	TrainTemplate.Parent = workspace
	CarriageTemplate.Parent = workspace

	TrainPosRemote.OnClientEvent:Connect(function(trainCFrame: CFrame, carriageCFrame: CFrame)
		if trainCFrame then
			TargetTrainCFrame = trainCFrame
		end
		if carriageCFrame then
			TargetCarriageCFrame = carriageCFrame
		end
	end)

	RunService.RenderStepped:Connect(function()
		if TargetTrainCFrame then
			CurrentTrainCFrame = CurrentTrainCFrame and CurrentTrainCFrame:Lerp(TargetTrainCFrame, LERP_ALPHA)
				or TargetTrainCFrame
		end
		if TargetCarriageCFrame then
			CurrentCarriageCFrame = CurrentCarriageCFrame
					and CurrentCarriageCFrame:Lerp(TargetCarriageCFrame, LERP_ALPHA)
				or TargetCarriageCFrame
		end
		if CurrentTrainCFrame and CurrentCarriageCFrame then
			workspace:BulkMoveTo(
				{ TrainTemplate.PrimaryPart, CarriageTemplate.PrimaryPart },
				{ CurrentTrainCFrame, CurrentCarriageCFrame },
				Enum.BulkMoveMode.FireCFrameChanged
			)
		end
	end)
end

return TrainHandler
