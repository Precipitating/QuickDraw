local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local HumanLimbGUIHandler = {}
HumanLimbGUIHandler.janitor = Janitor.new()
HumanLimbGUIHandler.networker = Networker.new("HumanLimbGUINetwork", HumanLimbGUIHandler)

function HumanLimbGUIHandler:UpdateLimbGUIHP(buf)
	local data = Sera.Deserialize(SeraSchemas.UpdateLimbGUIHPSchema, buf)

	PlayerContext:UpdateLimbsGUIHP(data.LimbName, data.LimbHealthPercentage)
end

return HumanLimbGUIHandler
