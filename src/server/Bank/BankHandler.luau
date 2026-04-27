local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local BankHandler = {}

function BankHandler:Deposit(player: Player, depositAmount: number)
	if depositAmount <= 0 then
		return
	end
	local currentCash = ServerData.GetMoney(player)

	if currentCash >= depositAmount then
		ServerData.UpdateMoney(player, -depositAmount)
		ServerData.UpdateBank(player, depositAmount)
	end
end

function BankHandler:Withdraw(player: Player, withdrawAmount: number)
	if withdrawAmount <= 0 then
		return
	end
	local currentCash = ServerData.GetBankBalance(player)

	if currentCash >= withdrawAmount then
		ServerData.UpdateBank(player, -withdrawAmount)
		ServerData.UpdateMoney(player, withdrawAmount)
	end
end
BankHandler.networker = Networker.new("BankNetwork", BankHandler, { BankHandler.Deposit, BankHandler.Withdraw })
return BankHandler
