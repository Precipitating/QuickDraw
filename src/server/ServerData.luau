local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Packages.DataService).server

local ServerData = {}
ServerData.Leaderstats = nil

function ServerData.Initialize()
	DataService:init({
		template = {
			currency = 0,
			bounty = 0,
			bank = 0,
			lastJoinedTime = nil,
			equippedWeapon = "CannonGun",
			equippedThrowable = nil,
			combatLogged = false,
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
	warn(player.Name .. " has initialized with data:", data)
	data.lastJoinedTime = os.time() -- We can directly modify data since no connections exist yet.
end

function ServerData.GetMoney(player: Player)
	return DataService:get(player, { "currency" })
end

function ServerData.UpdateMoney(player: Player, amount: number)
	DataService:update(player, "currency", function(currentAmt)
		warn(`{player.Name} should have {currentAmt + amount}`)
		return currentAmt + amount
	end)
end
function ServerData.SetMoney(player: Player, amount: number)
	DataService:set(player, { "currency" }, amount)
end
function ServerData.UpdateBounty(player: Player, amount: number)
	DataService:update(player, { "bounty" }, function(currentAmt)
		return currentAmt + amount
	end)
end

function ServerData.SetBounty(player: Player, amount: number)
	DataService:set(player, { "bounty" }, amount)
end

function ServerData:SetupLeaderboard(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local bounty: IntValue = Instance.new("IntValue")
	bounty.Name = "Bounty"
	bounty.Value = self.GetBounty(player)
	bounty.Parent = leaderstats
	ServerData.Leaderstats = leaderstats

	DataService:getChangedSignal(player, { "bounty" }):Connect(function(newBounty)
		warn(`[SERVER] NEW BOUNTY SHOULD BE {newBounty}`)
		bounty.Value = newBounty
	end)
end

function ServerData:SetupDataServiceEvents(player: Player)
	DataService:getChangedSignal(player, { "bounty" }):Connect(function(newValue)
		if newValue > 0 then
			if player.Character then
				CollectionService:AddTag(player.Character, "Wanted")
			else
				CollectionService:RemoveTag(player.Character, "Wanted")
			end
		end
	end)
end

function ServerData.UpdateBank(player: Player, amount: number)
	DataService:update(player, { "bank" }, function(currentAmt)
		return currentAmt + amount
	end)
end

function ServerData.SaveWeaponEquipped(player: Player, gunName: string)
	DataService:set(player, { "equippedWeapon" }, gunName)
end
function ServerData.GetThrowableData(player: Player)
	return DataService:get(player, { "equippedThrowable" })
end
function ServerData.GetWeaponName(player: Player)
	return DataService:get(player, { "equippedWeapon" })
end

function ServerData.SaveThrowableEquipped(player: Player, throwableName: string?, throwableAmmo: number?)
	DataService:set(player, { "equippedThrowable" }, { Name = throwableName, Ammo = throwableAmmo })
end
function ServerData.UpdateCombatLogged(player: Player, value: boolean)
	DataService:set(player, { "combatLogged" }, value)
end
function ServerData.HasCombatLogged(player: Player)
	return DataService:get(player, { "combatLogged" })
end
function ServerData.GetBankBalance(player: Player)
	return DataService:get(player, { "bank" })
end
function ServerData.GetBounty(player: Player)
	return DataService:get(player, { "bounty" })
end

return ServerData
