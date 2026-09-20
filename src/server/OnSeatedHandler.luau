local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local OnSeatedHandler = {}

function OnSeatedHandler:InformClientIfSeated(player: Player, seatType: string, seat: VehicleSeat? | Seat?)
	if not seat then
		Utility.Warn("[OnSeatedHandler:InformClientIfSeated] Missing seat instance")
		return
	end
	if seat.Occupant then
		self.networker:fire(player, "PlayerSeated", seatType, seat)
	else
		self.networker:fire(player, "PlayerUnSeated", "Horse")
	end
end

OnSeatedHandler.networker = Networker.new("OnSeatedNetwork", OnSeatedHandler, {})

return OnSeatedHandler
