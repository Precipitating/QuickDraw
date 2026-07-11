local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerData = require(script.Parent.ServerData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
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

function LootHandler:PickupLoot(player: Player, lootType: string, prompt: ProximityPrompt?)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
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
		local success = inventory:AddItem(prompt:GetAttribute("Type"), 1)

		if success then
			-- Destroy ore
			if prompt.Parent then
				prompt.Parent:Destroy()
			end
			QuestHandler:ProgressQuest(player, "Loot", 1)
			ServerSoundHandler:PlaySoundTo(player, "GenericPickup")
			return true
		end
	end
	return false
end

return LootHandler
