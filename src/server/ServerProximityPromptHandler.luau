local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopGUI = require(ServerScriptService.Server.GUI.ShopGUI)
local PurchasePrices = require(ReplicatedStorage.Shared.PurchasePrices)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ServerData = require(script.Parent.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerProximityPromptHandler = {}

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
function ServerProximityPromptHandler:CashPickedUp(player: Player, prompt: ProximityPrompt)
	if not prompt then
		return
	end
	local parent = prompt.Parent
	if not parent then
		return
	end
	local cashRegistered = parent:GetAttribute("Cash")

	if not cashRegistered then
		warn("Cash pickup has no Cash attribute")
		return
	end

	if cashRegistered > 0 then
		ServerData.UpdateMoney(player, cashRegistered)
		ServerSoundHandler:PlaySoundTo(player, "AddMoney")
		parent:Destroy()
	end
end

function ServerProximityPromptHandler:HealPlayer(player: Player, prompt: ProximityPrompt)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
		warn("Can't heal, human class missing")
		return
	end

	local money = ServerData.GetMoney(player)

	if money >= PurchasePrices.MEDIC_COST then
		ServerData.UpdateMoney(player, -PurchasePrices.MEDIC_COST)
		human:HealAll()
		ServerSoundHandler:PlaySoundTo(player, "MedicBuy")
	else
		ServerSoundHandler:PlaySoundTo(player, "Error")
	end
end

function ServerProximityPromptHandler:LootPickup(player: Player, lootType: string, prompt: ProximityPrompt?)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
		return
	end

	if lootType == "TumbleWeed" then
		if prompt and prompt.Parent then
			prompt.Parent:Destroy()
		end
		ShopGUI:BuyItem(player, RandomModule.WeightedRandom(TumbleWeedLootPool), 0, "TumbleWeedPickup")
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
				ShopGUI:BuyItem(player, RandomModule.WeightedRandom(TombStoneLootPool), 0, "SandPickup")
			end

			task.delay(TOMBSTONE_RESPAWN_TIME + RandomModule.GetRandomIntBetween(1, TOMBSTONE_RESPAWN_TIME), function()
				if tombstone and prompt then
					tombstone.Transparency = 0
					tombstone.CanCollide = true
					prompt.Enabled = true
				end
			end)
		end
	end
end

ServerProximityPromptHandler.networker = Networker.new("ProximityPromptNetwork", ServerProximityPromptHandler, {
	ServerProximityPromptHandler.CashPickedUp,
	ServerProximityPromptHandler.HealPlayer,
	ServerProximityPromptHandler.LootPickup,
})
return ServerProximityPromptHandler
