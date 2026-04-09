local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ShopGUI = {}

function ShopGUI:BuyItem(player: Player, productName: string, productCost: number)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
		warn("Human missing, can't buy")
		return false
	end

	local currentMoney = ServerData.GetMoney(player)
	local moneyIfPurchased = currentMoney - productCost
	if currentMoney and moneyIfPurchased < 0 then
		warn(`Can't afford {productName}`)
		return false
	end

	if GunData[productName] then
		if human.CurrentGun and human.CurrentGun.GunName == productName then
			return false
		end
		human:ChangeGun(productName)
		human.CurrentGun:AddGunToInventory()
	elseif ThrowableData[productName] then
		if human.CurrentThrowable and human.CurrentThrowable.Name == productName then
			human.CurrentThrowable.CurrentAmmo += 1
		else
			if human.CurrentThrowable then
				human.CurrentThrowable:Remove()
				human.CurrentThrowable:Destroy()
			end
			human.CurrentThrowable = Throwable.new(productName, human)
			human.CurrentThrowable:AddThrowableToInventory()
		end
	end

	ServerData.UpdateMoney(player, -productCost)
	return true
end
ShopGUI.networker = Networker.new("ShopNetwork", ShopGUI, { ShopGUI.BuyItem })
return ShopGUI
