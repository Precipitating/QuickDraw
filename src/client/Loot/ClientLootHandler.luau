local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientLootHandler = {}
ClientLootHandler.networker = Networker.new("LootNetwork", ClientLootHandler)

function ClientLootHandler:SellAllOres()
	local success = self.networker:fetch("SellAllOres")

	return success
end

return ClientLootHandler
