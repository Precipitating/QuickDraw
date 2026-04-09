local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Packages.DataService).server

local ServerData = {}

function ServerData.Initialize()
	DataService:init({
		template = {
			currency = 0,
		},
		profileStoreIndex = "Main",
		useMock = true,
		resetData = false,
	})
end

function ServerData.WaitForPlayerData(player: Player)
	return DataService:waitForData(player)
end

function ServerData.UpdateMoney(player: Player, amount: number)
	DataService:update(player, "currency", function(currentAmt)
		warn(`{player.Name} should have {currentAmt + amount}`)
		return currentAmt + amount
	end)
end

function ServerData.GetMoney(player: Player)
	return DataService:get(player, { "currency" })
end

return ServerData
