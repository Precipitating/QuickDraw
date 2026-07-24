local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local OnSeatedClientHandler = {}
OnSeatedClientHandler.networker = Networker.new("OnSeatedNetwork", OnSeatedClientHandler)

function OnSeatedClientHandler:PlayerSeated(seatType: string, seat: Seat?)
	workspace.CurrentCamera.CameraSubject = PlayerContext.Humanoid
	if seatType == "Horse" then
		print("Sat on horse!")
	end
end
function OnSeatedClientHandler:PlayerUnSeated(seatType: string)
	if seatType == "Horse" then
		print("Unsat on horse!")
	end
end

return OnSeatedClientHandler
