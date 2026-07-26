local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LootHandler = require(script.Parent.LootHandler)
local PurchasePrices = require(ReplicatedStorage.Shared.PurchasePrices)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ServerData = require(script.Parent.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerProximityPromptHandler = {}

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
	LootHandler:PickupLoot(player, lootType, prompt)
end

function ServerProximityPromptHandler:HorseMount(player: Player, prompt: ProximityPrompt?)
	if not prompt then
		return
	end

	local vehicleSeat = prompt.Parent and prompt.Parent:FindFirstChildOfClass("VehicleSeat")

	if not vehicleSeat then
		warn("Horse has no vehicle seat")
		prompt.Enabled = true
		return
	end
	local character = player.Character
	if not character then
		warn("[ServerProximityPromptHandler:HorseMount] Missing character?")
		prompt.Enabled = true
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[ServerProximityPromptHandler:HorseMount] Missing humanoid")
		prompt.Enabled = true
		return
	end
	local distance = (character.PrimaryPart.Position - vehicleSeat.Position).Magnitude

	if distance > 10 then
		warn(`{player.Name} tried to mount horse but not close enough.`)
		prompt.Enabled = true
		return
	end

	if not vehicleSeat.Occupant then
		vehicleSeat:Sit(humanoid)
	end
end

ServerProximityPromptHandler.networker = Networker.new("ProximityPromptNetwork", ServerProximityPromptHandler, {
	ServerProximityPromptHandler.CashPickedUp,
	ServerProximityPromptHandler.HealPlayer,
	ServerProximityPromptHandler.LootPickup,
	ServerProximityPromptHandler.HorseMount,
})
return ServerProximityPromptHandler
