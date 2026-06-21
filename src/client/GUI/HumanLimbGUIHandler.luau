local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local HumanLimbGUIHandler = {}
HumanLimbGUIHandler.janitor = Janitor.new()
HumanLimbGUIHandler.networker = Networker.new("HumanLimbGUINetwork", HumanLimbGUIHandler)

function HumanLimbGUIHandler:UpdateLimbGUIHP(limbName: string, limbHealthPercentage: number?)
	PlayerContext:UpdateLimbsGUIHP(limbName, limbHealthPercentage)
end

return HumanLimbGUIHandler
