local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HumanLimbGUIHandler = {}

function HumanLimbGUIHandler:UpdateLimbGUIHP(player: Player, limbName: string, limbHealthPercentage: number?)
	local buf, err = Sera.Serialize(SeraSchemas.UpdateLimbGUIHPSchema, {
		LimbName = limbName,
		LimbHealthPercentage = limbHealthPercentage,
	})

	if not buf then
		error(err)
	end

	self.networker:fire(player, "UpdateLimbGUIHP", buf)
end

HumanLimbGUIHandler.networker = Networker.new("HumanLimbGUINetwork", HumanLimbGUIHandler)
return HumanLimbGUIHandler
