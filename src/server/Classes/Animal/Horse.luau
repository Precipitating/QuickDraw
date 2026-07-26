local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Animal class
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local OnSeatedHandler = require(ServerScriptService.Server.OnSeatedHandler)

local Animal = require(script.Parent.Animal)
local AnimalData = require(script.Parent.AnimalData)
local Horse = setmetatable({}, Animal)
Horse.__index = Horse

function Horse.new(model: Model?, classType: string)
	local self = setmetatable(Animal.new(model, classType, false), Horse)
	if not model then
		warn("Horse class missing model!")
		return
	end
	------------------------------------------------------------------------
	self.Seat = model:FindFirstChildOfClass("VehicleSeat") :: VehicleSeat?
	self.LinearVelocity = model:FindFirstChildOfClass("LinearVelocity") :: LinearVelocity?
	self.CurrentSeatedPlayer = nil
	self.CurrentSpeed = 0
	self.ProximityPrompt = model:FindFirstChildOfClass("ProximityPrompt")
	self.BodyParts = {
		Head = Utility.GetInstance(model, false, "Head"),
		Torso = Utility.GetInstance(model, false, "Torso"),

		FrontLeftUpperLeg = Utility.GetInstance(model, false, "FLUF"),
		FrontLeftLowerLeg = Utility.GetInstance(model, false, "FLLF"),

		FrontRightUpperLeg = Utility.GetInstance(model, false, "FR-LF"),
		FrontRightLowerLeg = Utility.GetInstance(model, false, "FLLF"),

		BackLeftUpperLeg = Utility.GetInstance(model, false, "BLUL"),
		BackLeftLowerLeg = Utility.GetInstance(model, false, "BLL"),

		BackRightUpperLeg = Utility.GetInstance(model, false, "BRUL"),
		BackRightLowerLeg = Utility.GetInstance(model, false, "BRLL"),
	}
	if not self.Seat then
		warn("Horse missing seat!")
		return
	end
	if not self.LinearVelocity then
		self.LinearVelocity = Instance.new("LinearVelocity")
		self.LinearVelocity.Parent = model
	end
	------------------------------------------------------------------------

	self:ConnectSeat()
	return self :: any
end

function Horse:ConnectMovement()
	self.Janitor:Add(
		RunService.Heartbeat:Connect(function(dt)
			local seat = self.Seat
			if not self.Seat then
				return
			end
			local throttle = seat.Throttle
			local currentSpeed = self.CurrentSpeed
			local acceleration = AnimalData.Horse.Acceleration
			local deceleration = AnimalData.Horse.Deceleration
			local targetSpeed = nil
			local linearVelocity: LinearVelocity = self.LinearVelocity
			------------------------------------------------------------------------

			targetSpeed = if throttle >= 0
				then throttle * AnimalData.Horse.MaxForwardSpeed
				else throttle * AnimalData.Horse.MaxReverseSpeed

			if math.abs(targetSpeed) > math.abs(currentSpeed) then
				currentSpeed = currentSpeed + math.sign(targetSpeed - currentSpeed) * acceleration * dt
				-- clamp so we don't overshoot target
				if
					(targetSpeed > 0 and currentSpeed > targetSpeed)
					or (targetSpeed < 0 and currentSpeed < targetSpeed)
				then
					currentSpeed = targetSpeed
				end
			else
				-- decelerate toward target (including toward 0 when Throttle released)
				currentSpeed = currentSpeed + math.sign(targetSpeed - currentSpeed) * deceleration * dt
				if math.abs(currentSpeed - targetSpeed) < 0.5 then
					currentSpeed = targetSpeed
				end
			end
			self.CurrentSpeed = currentSpeed
			linearVelocity.VectorVelocity = Vector3.new(0, 0, -currentSpeed) -- -Z is forward in local space
		end),
		"Disconnect",
		"HorseMovementConn"
	)
end

function Horse:Die(killer: Player?)
	if self.Seat then
		self.Seat.Disabled = true
	end
	if self.CurrentSeatedPlayer then
		local human = PlayerManager:GetHumanClassFromPlayer(self.CurrentSeatedPlayer)

		if human then
			if self.CurrentSpeed > 20 then
				human:Ragdoll(5)
			end
		end
	end

	if self.ProximityPrompt then
		self.ProximityPrompt:Destroy()
	end
	Animal.Die(self, killer)
end
function Horse:ConnectSeat()
	local seat = self.Seat
	local linearVel: LinearVelocity = self.LinearVelocity
	linearVel.Enabled = false
	linearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	seat.MaxSpeed = 0

	self.Janitor:Add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant

		if occupant then
			local character = occupant.Parent
			local player = Players:GetPlayerFromCharacter(character)

			if not player then
				return
			end
			if self.ProximityPrompt then
				self.ProximityPrompt.Enabled = false
			end
			self.CurrentSeatedPlayer = player
			linearVel.Enabled = true
			self:ConnectMovement()
			OnSeatedHandler:InformClientIfSeated(player, "Horse", seat)
		else
			seat.Throttle = 0
			seat.Steer = 0
			linearVel.VectorVelocity = Vector3.zero
			linearVel.Enabled = false
			if self.ProximityPrompt then
				self.ProximityPrompt.Enabled = true
			end
			self.Janitor:Remove("HorseMovementConn")
			OnSeatedHandler:InformClientIfSeated(self.CurrentSeatedPlayer, "Horse", seat)
			self.CurrentSeatedPlayer = nil
		end
	end))
end
return Horse
