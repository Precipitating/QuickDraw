local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local ServerData = require(script.Parent.ServerData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local OreData = require(ServerScriptService.Server.Ore.OreData)
local QuestHandler = require(ServerScriptService.Server.Quests.QuestHandler)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)

local TumbleWeedLootPool = {
	{ value = "Winchester", weight = 5 },
	{ value = "Coach", weight = 10 },
	{ value = "Dynamite", weight = 40 },
	{ value = "KetchumGrenade", weight = 20 },
	{ value = "Molotov", weight = 25 },
}

local TombStoneLootPool = {
	{ value = "Coach", weight = 5 },
	{ value = "Dynamite", weight = 20 },
	{ value = "KetchumGrenade", weight = 10 },
	{ value = "Molotov", weight = 15 },
	{ value = "BearTrap", weight = 15 },
	{ value = "TripMine", weight = 15 },
	{ value = "RopeTrap", weight = 20 },
}

local TOMBSTONE_RESPAWN_TIME = 300
local TOMBSTONE_CASH_REWARD_CHANCE = 0.05
local TOMBSTONE_CASH_REWARD_MAX = 500
local LootHandler = {}

-- Anti exploit checks
local function CanPickup(player: Player, prompt: ProximityPrompt?)
	if not prompt then
		return false
	end
	local promptParent = prompt.Parent

	if not promptParent then
		return false
	end
	local character = player.Character

	if not promptParent:IsA("BasePart") then
		return
	end

	local dist = (promptParent.Position - character:GetPivot().Position).Magnitude

	if dist > 30 then
		return false
	end

	return true
end

function LootHandler:PickupLoot(player: Player, lootType: string, prompt: ProximityPrompt?)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
		return false
	end

	if not CanPickup(player, prompt) then
		return false
	end

	if lootType == "TumbleWeed" then
		if prompt and prompt.Parent then
			prompt.Parent:Destroy()
		end
		local chosenLoot = RandomModule.WeightedRandom(TumbleWeedLootPool)
		self.networker:fire(player, "ConnectLootPickupGUI", lootType, chosenLoot)
		return true
		--ShopGUI:BuyItem(player, chosenLoot, 0, "TumbleWeedPickup")
	elseif lootType == "Tombstone" then
		local tombstone: MeshPart? = prompt and prompt.Parent :: MeshPart?

		if tombstone and prompt then
			tombstone.Transparency = 1
			tombstone.CanCollide = false
			prompt.Enabled = false
			local cashReward = RandomModule.GetRandom() <= TOMBSTONE_CASH_REWARD_CHANCE

			if cashReward then
				ServerData.UpdateMoney(player, RandomModule.GetRandomIntBetween(1, TOMBSTONE_CASH_REWARD_MAX))
			else
				local chosenLoot = RandomModule.WeightedRandom(TombStoneLootPool)
				self.networker:fire(player, "ConnectLootPickupGUI", lootType, chosenLoot)
				--ShopGUI:BuyItem(player, RandomModule.WeightedRandom(TombStoneLootPool), 0, "SandPickup")
			end

			task.delay(TOMBSTONE_RESPAWN_TIME + RandomModule.GetRandomIntBetween(1, TOMBSTONE_RESPAWN_TIME), function()
				if tombstone and prompt then
					tombstone.Transparency = 0
					tombstone.CanCollide = true
					prompt.Enabled = true
				end
			end)

			return true
		end
	elseif lootType == "Ore" then
		local inventory = human.Inventory
		if not inventory then
			warn("Ore looting: Missing human inventory")
			return false
		end

		if not prompt then
			warn("Ore looting: Missing prompt")
			return false
		end

		if not inventory.AddItem then
			warn("Ore looting: Missing AddItem function")
			return false
		end

		local oreName = prompt:GetAttribute("Type")
		if not oreName then
			warn("Ore looting: Missing ore name (check if prompt has Attribute called Type)")
			return false
		end
		local success = inventory:AddItem(oreName, 1)

		if success then
			-- Destroy ore
			if prompt.Parent then
				prompt.Parent:Destroy()
			end
			PopupGUI:NewPopup(player, 2, `Added {oreName} to inventory!`)
			QuestHandler:ProgressQuest(player, "Loot", 1)
			ServerSoundHandler:PlaySoundTo(player, "GenericPickup")
			return true
		end
	end
	return false
end

function LootHandler:SellAllOres(player: Player)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	local moneyMade = 0
	if not human then
		warn("Cannot sell ore, human class missing")
		return false
	end

	local inventory = human.Inventory
	if not inventory then
		warn("Cannot sell ore, inventory class missing")
		return false
	end

	local itemsStored = inventory:GetStoredItems()

	for key, table in itemsStored do
		local oreData = OreData[key]
		if not oreData then
			continue
		end

		moneyMade += oreData.worth * table.Quantity
		inventory:RemoveItem(key)
	end

	if moneyMade <= 0 then
		return false
	end

	ServerData.UpdateMoney(player, moneyMade)
	PopupGUI:NewPopup(player, 2, `Earned ${moneyMade} from selling ores!`)
	return true
end
LootHandler.networker = Networker.new("LootNetwork", LootHandler, { LootHandler.SellAllOres })
return LootHandler
