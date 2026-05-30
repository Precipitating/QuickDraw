local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SplineClass = require(ReplicatedStorage.Shared.SplineClass)
local TrainPaths = ReplicatedStorage.Shared.Paths.TrainPaths
local TrainPositions = {}
local CreatedSpline = nil
local TrainModels = nil
local CarriageModels = nil
local SPEED = 50
local CARRIAGE_OFFSET = 80
local SLOW_RADIUS = 50
local COOLDOWN_TIME = 5
local LoopConn = nil
local StationPoints = {}
local Stopped = false
local CurrentSpeed = SPEED

local TrainHandler = {}

local function GetTargetSpeed(trainPos)
	if Stopped then
		return 0
	end

	local closest = math.huge
	for _, stop in StationPoints do
		if not stop.triggered and not stop.cooldown then
			local dist = (trainPos - stop.part.Position).Magnitude
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

	local distance = CARRIAGE_OFFSET * #CarriageModels

	LoopConn = RunService.Heartbeat:Connect(function(dt)
		local trainPos = TrainModels[1]:GetPivot().Position

		for _, stop in StationPoints do
			if not stop.triggered and not stop.cooldown and (trainPos - stop.part.Position).Magnitude < 10 then
				stop.triggered = true
				Stopped = true
				task.delay(stop.stopFor, function()
					Stopped = false
					stop.cooldown = true
					task.delay(COOLDOWN_TIME, function()
						stop.cooldown = false
						stop.triggered = false
					end)
				end)
			end
		end

		local targetSpeed = GetTargetSpeed(trainPos)
		CurrentSpeed = CurrentSpeed + (targetSpeed - CurrentSpeed) * (dt * 3)
		distance = distance + CurrentSpeed * dt

		for _, trainModel in TrainModels do
			trainModel.PrimaryPart.CFrame = CreatedSpline:GetCFrame(distance % CreatedSpline.Length, true)
		end
		for i, carriageModel in CarriageModels do
			local carriageDistance = (distance - (CARRIAGE_OFFSET * i)) % CreatedSpline.Length
			carriageModel.PrimaryPart.CFrame = CreatedSpline:GetCFrame(carriageDistance, true)
		end
	end)
end

function TrainHandler:Initialize()
	if not TrainPaths then
		return
	end

	for i = 1, #TrainPaths:GetChildren() do
		local part = TrainPaths[tostring(i)]
		TrainPositions[i] = part.Position
		if CollectionService:HasTag(part, "StationPoint") then
			table.insert(StationPoints, {
				part = part,
				stopFor = part:GetAttribute("StopDuration") or 60,
				triggered = false,
				cooldown = false,
			})
		end
	end

	TrainModels = CollectionService:GetTagged("Train")
	if #TrainModels <= 0 then
		warn("No train tags found")
		return
	end

	CarriageModels = CollectionService:GetTagged("Carriage")
	if #CarriageModels <= 0 then
		warn("No carriage tags found")
		return
	end

	CreatedSpline = SplineClass.new(TrainPositions, { Tension = 1, Looped = true })
	self:Run(true)
end

return TrainHandler
