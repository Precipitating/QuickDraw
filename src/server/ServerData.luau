local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local DataService = require(ReplicatedStorage.Packages.DataService).server

local ServerData = {}
ServerData.Leaderstats = nil

function ServerData.Initialize()
	DataService:init({
		template = {
			currency = 0,
			bounty = 0,
			lastJoinedTime = nil,
		},
		profileStoreIndex = "Main",
		useMock = true,
		resetData = false,
	})
end

function ServerData.WaitForPlayerData(player: Player)
	return DataService:waitForData(player)
end

function DataService:onPlayerInit(player: Player, data): ()
	print(player.Name .. " has initialized with data:", data)
	data.lastJoinedTime = os.time() -- We can directly modify data since no connections exist yet.
end

function ServerData.UpdateMoney(player: Player, amount: number)
	DataService:update(player, "currency", function(currentAmt)
		warn(`{player.Name} should have {currentAmt + amount}`)
		return currentAmt + amount
	end)
end

function ServerData.UpdateBounty(player: Player, amount: number)
	local finalBounty = nil
	DataService:update(player, "bounty", function(currentAmt)
		finalBounty = currentAmt + amount
		return finalBounty
	end)

	-- leaderstat update
	local playerStats = Utility.GetInstance(player, false, "leaderstats")
	local bounty: IntValue = Utility.GetInstance(playerStats, false, "Bounty")

	bounty.Value = finalBounty
end

function ServerData.SetBounty(player: Player, amount: number)
	DataService:update(player, "bounty", function(_)
		return amount
	end)
end

function ServerData:SetupLeaderboard(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local bounty = Instance.new("IntValue")
	bounty.Name = "Bounty"
	bounty.Value = self:GetBounty(player)
	bounty.Parent = leaderstats
	ServerData.Leaderstats = leaderstats
end

function ServerData.GetMoney(player: Player)
	return DataService:get(player, { "currency" })
end

function ServerData:GetBounty(player: Player)
	return DataService:get(player, { "bounty" })
end

return ServerData
