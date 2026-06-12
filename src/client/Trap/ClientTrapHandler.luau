local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientTrapHandler = {}

ClientTrapHandler.networker = Networker.new("TrapNetwork", ClientTrapHandler)
local InnerTrapJanitor = Janitor.new()
local OuterTrapJanitor = Janitor.new()

function ClientTrapHandler:ConnectTrap(trap: Tool?)
	if not trap then
		return
	end

	OuterTrapJanitor:Add(trap.Equipped:Connect(function()
		warn("Trap connected")
		local trapData = TrapData[trap.Name]

		InnerTrapJanitor:Cleanup() -- clear previous equip if any
		InnerTrapJanitor:Add(trap.Activated:Connect(function()
			SoundManager.PlayKeyed("SFX", trapData.PlaceSoundName)
			ClientTrapHandler.networker:fire("PlaceDownTrap", trap)
		end))
	end))

	OuterTrapJanitor:Add(trap.Unequipped:Connect(function()
		warn("Trap disconnected")
		InnerTrapJanitor:Cleanup()
	end))

	OuterTrapJanitor:Add(trap.Destroying:Connect(function()
		InnerTrapJanitor:Cleanup()
		OuterTrapJanitor:Cleanup()
	end))
end

return ClientTrapHandler
