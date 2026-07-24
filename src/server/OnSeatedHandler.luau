local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimalData = require(ServerScriptService.Server.Classes.Animal.AnimalData)
local Networker = require(ReplicatedStorage.Packages.Networker).server

local OnSeatedHandler = {}

local SeatedPlayers = {}

local function UpdateHorseMovement(linearVel: LinearVelocity?, seat: VehicleSeat?)
	if not seat or not linearVel then
		return
	end
	local fwdSpeed = AnimalData.Horse.ForwardSpeed
	local reverseSpeed = AnimalData.Horse.ReverseSpeed
	local throttle = seat.Throttle

	if throttle > 0 then
		-- Moving Forward (Z axis is negative in Roblox object space)
		linearVel.VectorVelocity = Vector3.new(0, 0, -fwdSpeed)
	elseif throttle < 0 then
		-- Backing Up
		linearVel.VectorVelocity = Vector3.new(0, 0, reverseSpeed)
	else
		-- Stopped
		linearVel.VectorVelocity = Vector3.zero
	end
end

function OnSeatedHandler:OnHorseSeatSat()
	CollectionService:GetInstanceAddedSignal("HorseSeat"):Connect(function(seat: VehicleSeat?)
		if not seat then
			return
		end
		local linearVel = seat.Parent and seat.Parent:FindFirstChildOfClass("LinearVelocity")

		if not linearVel then
			warn("Horse missing linear velocity instance")
			return
		end

		seat:GetPropertyChangedSignal("Throttle"):Connect(function()
			UpdateHorseMovement(linearVel, seat)
		end)

		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occupant = seat.Occupant

			if occupant then
				local character = occupant.Parent
				local player = Players:GetPlayerFromCharacter(character)

				if not player then
					return
				end
				SeatedPlayers[seat] = player

				self.networker:fire(player, "PlayerSeated", "Horse", seat)
			else
				local lastSatPlayer = SeatedPlayers[seat]
				seat.Throttle = 0
				seat.Steer = 0
				linearVel.VectorVelocity = Vector3.zero
				if not lastSatPlayer then
					return
				end

				self.networker:fire(lastSatPlayer, "PlayerUnSeated", "Horse")
			end
		end)
	end)
end

function OnSeatedHandler:Initialize()
	self:OnHorseSeatSat()
end

OnSeatedHandler.networker = Networker.new("OnSeatedNetwork", OnSeatedHandler, {})

return OnSeatedHandler
