local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local OnSeatedHandler = {}

function OnSeatedHandler:InformClientIfSeated(player: Player, seatType: string, seat: VehicleSeat? | Seat?)
	if not seat then
		warn("[OnSeatedHandler:InformClientIfSeated] Missing seat instance")
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
