local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanLimbGUIHandler = {}

function HumanLimbGUIHandler:UpdateLimbGUIHP(player: Player, limbName: string, limbHealthPercentage: number)
	self.networker:fire(player, "UpdateLimbGUIHP", limbName, limbHealthPercentage)
end

HumanLimbGUIHandler.networker = Networker.new("HumanLimbGUINetwork", HumanLimbGUIHandler)
return HumanLimbGUIHandler
