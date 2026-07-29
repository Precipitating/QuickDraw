local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local SplineClass = require(ReplicatedStorage.Shared.SplineClass)
local Templates = ReplicatedStorage.Shared.Templates
local TrainPosRemote = ReplicatedStorage.Shared.Remote.TrainPositionRemote
local TrainPosSchema = SeraSchemas.TrainPositionSchema
local TrainPaths = ReplicatedStorage.Shared.Paths.TrainPaths

local TrainHandler = {}

local TrainTemplate = nil
local CarriageTemplate = nil
local ClientSpline = nil

local CARRIAGE_OFFSET = 78
local ServerDistance = 0
local ClientDistance = 0
local CurrentSpeed = 0
local PredictedSpeed = 0
local SPEED_SMOOTH = 8 -- how fast speed estimate catches up
local CORRECT_GAIN = 3 -- gentle correction, not 5 (reduces rubber-band)
local SNAP_THRESHOLD = 15 -- only hard-snap if VERY desynced

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
		return
	end

	TrainTemplate.PrimaryPart = TrainTemplate:FindFirstChild("BASE", true)
	CarriageTemplate.PrimaryPart = CarriageTemplate:FindFirstChild("BASE", true)

	local trainRope = TrainTemplate:FindFirstChildOfClass("RopeConstraint")
	local carriageAttachPoint = CarriageTemplate:FindFirstChild("AttachPoint", true)
	if trainRope and carriageAttachPoint then
		trainRope.Attachment1 = carriageAttachPoint
	end

	DisableCollisions(TrainTemplate)

	TrainTemplate.Parent = workspace
	CarriageTemplate.Parent = workspace

	-- 1. Build the Spline on the Client so it knows the track
	local TrainPositions = {}
	for i = 1, #TrainPaths:GetChildren(), 1 do
		local part = TrainPaths:WaitForChild(`TrackPath_{i}`, 1)
		if part then
			TrainPositions[i] = part.Position
		end
	end
	ClientSpline = SplineClass.new(TrainPositions, { Tension = 1, Looped = true })

	-- Smoothing constants

	TrainPosRemote.OnClientEvent:Connect(function(buf)
		local data = Sera.Deserialize(TrainPosSchema, buf)
		ServerDistance = data.Distance
		CurrentSpeed = data.CurrentSpeed

		-- Only hard-snap if wildly out of sync
		if math.abs(ClientDistance - ServerDistance) > SNAP_THRESHOLD then
			ClientDistance = ServerDistance
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not ClientSpline then
			return
		end

		-- 1. Smooth our local speed estimate toward the server's reported speed
		PredictedSpeed = PredictedSpeed + (CurrentSpeed - PredictedSpeed) * (dt * SPEED_SMOOTH)

		-- 2. Dead-reckon forward using smoothed speed
		ClientDistance = ClientDistance + PredictedSpeed * dt

		-- 3. Gently nudge toward server distance — low gain prevents rubber-band
		local correction = (ServerDistance - ClientDistance) * (dt * CORRECT_GAIN)
		ClientDistance = ClientDistance + correction

		-- 4. Sample spline
		local len = ClientSpline.Length
		local trainCFrame = ClientSpline:GetCFrame(ClientDistance % len, true)
		local carriageCFrame = ClientSpline:GetCFrame((ClientDistance - CARRIAGE_OFFSET) % len, true)

		-- 5. BulkMoveTo — moves the weld root, Roblox handles descendants via welds
		workspace:BulkMoveTo(
			{ TrainTemplate.PrimaryPart, CarriageTemplate.PrimaryPart },
			{ trainCFrame, carriageCFrame },
			Enum.BulkMoveMode.FireCFrameChanged
		)
	end)
end

return TrainHandler
