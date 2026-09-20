local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LootHandler = require(script.Parent.LootHandler)
local PurchasePrices = require(ReplicatedStorage.Shared.PurchasePrices)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
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
		Utility.Warn("Cash pickup has no Cash attribute")
		return
	end

	if cashRegistered > 0 then
		ServerData.UpdateMoney(player, cashRegistered)
		ServerSoundHandler:PlaySoundTo(player, "AddMoney")
		parent:Destroy()
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
		Utility.Warn("Horse has no vehicle seat")
		prompt.Enabled = true
		return
	end
	local character = player.Character
	if not character then
		Utility.Warn("[ServerProximityPromptHandler:HorseMount] Missing character?")
		prompt.Enabled = true
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		Utility.Warn("[ServerProximityPromptHandler:HorseMount] Missing humanoid")
		prompt.Enabled = true
		return
	end
	local distance = (character.PrimaryPart.Position - vehicleSeat.Position).Magnitude

	if distance > 10 then
		Utility.Warn(`{player.Name} tried to mount horse but not close enough.`)
		prompt.Enabled = true
		return
	end

	if not vehicleSeat.Occupant then
		vehicleSeat:Sit(humanoid)
	end
end

ServerProximityPromptHandler.networker = Networker.new("ProximityPromptNetwork", ServerProximityPromptHandler, {
	ServerProximityPromptHandler.CashPickedUp,
	ServerProximityPromptHandler.LootPickup,
	ServerProximityPromptHandler.HorseMount,
})
return ServerProximityPromptHandler
