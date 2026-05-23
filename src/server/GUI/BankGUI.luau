local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CommonGUIFunctions = require(script.Parent.CommonGUIFunctions)
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local BankGUI = {}

function BankGUI:GetBankBalance(player: Player)
	return ServerData.GetBankBalance(player)
end

function BankGUI:Deposit(player: Player, depositAmount: number)
	if depositAmount <= 0 then
		return false
	end
	local currentCash = ServerData.GetMoney(player)

	if currentCash < depositAmount then
		return false
	end

	ServerData.UpdateMoney(player, -depositAmount)
	ServerData.UpdateBank(player, depositAmount)

	return true
end

function BankGUI:OnGUIOpen(player: Player, npcModel: Model)
	CommonGUIFunctions:OnGUIOpen(player, npcModel)
end
function BankGUI:OnGUIClose(player: Player)
	CommonGUIFunctions:OnGUIClose(player)
end

function BankGUI:Withdraw(player: Player, withdrawAmount: number)
	if withdrawAmount <= 0 then
		return false
	end
	local currentCash = ServerData.GetBankBalance(player)

	if currentCash < withdrawAmount then
		return false
	end

	ServerData.UpdateBank(player, -withdrawAmount)
	ServerData.UpdateMoney(player, withdrawAmount)
	return true
end
BankGUI.networker = Networker.new(
	"BankNetwork",
	BankGUI,
	{ BankGUI.Deposit, BankGUI.Withdraw, BankGUI.GetBankBalance, BankGUI.OnGUIOpen, BankGUI.OnGUIClose }
)
return BankGUI
