local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local BankHandler = {}

function BankHandler:GetBankBalance(player: Player)
	return ServerData.GetBankBalance(player)
end

function BankHandler:Deposit(player: Player, depositAmount: number)
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

function BankHandler:Withdraw(player: Player, withdrawAmount: number)
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
BankHandler.networker =
	Networker.new("BankNetwork", BankHandler, { BankHandler.Deposit, BankHandler.Withdraw, BankHandler.GetBankBalance })
return BankHandler
