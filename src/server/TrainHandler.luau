local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SplineClass = require(ReplicatedStorage.Shared.SplineClass)
local TrainPaths = ReplicatedStorage.Shared.Paths.TrainPaths
local TrainPositions = {}
local CreatedSpline = nil
local TrainModel = nil
local CarriageModel = nil
local SPEED = 50
local CARRIAGE_OFFSET = 78
local SLOW_RADIUS = 50
local COOLDOWN_TIME = 5
local LoopConn = nil
local StationPoints = {}
local Stopped = false
local CurrentSpeed = SPEED
local TrainPosRemote = ReplicatedStorage.Shared.Remote.TrainPositionRemote

local TrainHandler = {}

local function GetTargetSpeed(trainPos)
	if Stopped then
		return 0
	end

	local closest = math.huge
	for _, stop in StationPoints do
		if not stop.Triggered and not stop.Cooldown then
			local dist = (trainPos - stop.Position).Magnitude
			if dist < closest then
				closest = dist
			end
		end
	end

	if closest < SLOW_RADIUS then
		return SPEED * (closest / SLOW_RADIUS)
	end

	return SPEED
end

function TrainHandler:Run(active: boolean)
	if not active then
		if LoopConn then
			LoopConn:Disconnect()
			LoopConn = nil
		end
		return
	end

	local distance = CARRIAGE_OFFSET

	LoopConn = RunService.Heartbeat:Connect(function(dt)
		if not CarriageModel then
			warn("No carriage found on server")
			return
		end

		if not TrainModel then
			warn("No train found on server")
			return
		end
		local trainPos = TrainModel:GetPivot().Position

		for _, stop in StationPoints do
			if not stop.Triggered and not stop.Cooldown and (trainPos - stop.Position).Magnitude < 10 then
				stop.Triggered = true
				Stopped = true
				task.delay(stop.StopFor, function()
					Stopped = false
					stop.Cooldown = true
					task.delay(COOLDOWN_TIME, function()
						stop.Cooldown = false
						stop.Triggered = false
					end)
				end)
			end
		end

		local targetSpeed = GetTargetSpeed(trainPos)
		CurrentSpeed = CurrentSpeed + (targetSpeed - CurrentSpeed) * (dt * 3)
		distance = distance + CurrentSpeed * dt

		local trainCFrame = CreatedSpline:GetCFrame(distance % CreatedSpline.Length, true)
		local carriageDistance = (distance - CARRIAGE_OFFSET) % CreatedSpline.Length
		local carriageCFrame = CreatedSpline:GetCFrame(carriageDistance, true)

		local partsToMove = { CarriageModel.PrimaryPart, TrainModel }
		local targetCFrames = { carriageCFrame, trainCFrame }

		-- Move everything safely in a single engine operation
		workspace:BulkMoveTo(partsToMove, targetCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		TrainPosRemote:FireAllClients(trainCFrame, carriageCFrame, workspace:GetServerTimeNow())
	end)
end

function TrainHandler:Initialize()
	if not TrainPaths then
		return
	end

	for i = 1, #TrainPaths:GetChildren() do
		local part = TrainPaths[`Seg_{i}`]
		TrainPositions[i] = part.Position
		if CollectionService:HasTag(part, "StationPoint") then
			table.insert(StationPoints, {
				Position = part.Position,
				StopFor = part:GetAttribute("StopDuration") or 60,
				Triggered = false,
				Cooldown = false,
			})
		end
	end
	TrainPaths:Destroy()
	TrainModel = workspace:FindFirstChild("ServerTrain")
	if not TrainModel then
		warn("No train found on server")
		return
	end
	CarriageModel = workspace:FindFirstChild("ServerCarriage")
	if not CarriageModel then
		warn("No carriage found on server")
		return
	end

	CreatedSpline = SplineClass.new(TrainPositions, { Tension = 1, Looped = true })
	self:Run(true)
end

return TrainHandler
