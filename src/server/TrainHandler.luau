local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SplineClass = require(ReplicatedStorage.Shared.SplineClass)
local TrainPaths = ReplicatedStorage.Shared.Paths.TrainPaths
local TrainPositions = {}
local CreatedSpline = nil
local TrainModel = nil
local CarriageModel = nil
local NetSendAccum = 0
local NET_SEND_RATE = 1 / 20 -- 20 times per second is plenty
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
		-- if not CarriageModel then
		-- 	warn("No carriage found on server")
		-- 	return
		-- end

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
		TrainModel:PivotTo(trainCFrame)

		NetSendAccum = NetSendAccum + dt
		if NetSendAccum >= NET_SEND_RATE then
			NetSendAccum = 0
			TrainPosRemote:FireAllClients(distance, CurrentSpeed)
		end
	end)
end

function TrainHandler:Initialize()
	if not TrainPaths then
		return
	end

	for i = 1, #TrainPaths:GetChildren(), 1 do
		local part = TrainPaths:FindFirstChild(`TrackPath_{i}`)
		if not part then
			continue
		end
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
	TrainModel = workspace:FindFirstChild("ServerTrain")
	if not TrainModel then
		warn("No train found on server")
		return
	end

	CreatedSpline = SplineClass.new(TrainPositions, { Tension = 1, Looped = true })
	self:Run(true)
end

return TrainHandler
