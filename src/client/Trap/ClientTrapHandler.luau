local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientTrapNetwork = require(script.Parent.ClientTrapNetwork)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClientTrapHandler = {}

local TrapJanitor = Janitor.new()
function ClientTrapHandler:ConnectTrap(trap: Tool?)
	if not trap then
		return
	end

	TrapJanitor:Cleanup()
	TrapJanitor:Add(trap.Activated:Connect(function()
		ClientTrapNetwork.networker:fire("PlaceDownTrap", trap)
	end))
end

return ClientTrapHandler
