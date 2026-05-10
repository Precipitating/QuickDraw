local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
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

	human:HealAll()
end

ServerProximityPromptHandler.networker = Networker.new(
	"ProximityPromptNetwork",
	ServerProximityPromptHandler,
	{ ServerProximityPromptHandler.CashPickedUp, ServerProximityPromptHandler.HealPlayer }
)
return ServerProximityPromptHandler
