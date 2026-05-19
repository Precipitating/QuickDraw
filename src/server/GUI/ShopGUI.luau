local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CommonGUIFunctions = require(script.Parent.CommonGUIFunctions)
local ShopCosts = require(script.Parent.ShopCosts)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerData = require(ServerScriptService.Server.ServerData)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ShopGUI = {}

function ShopGUI:OnGUIOpen(player: Player, npcModel: Model)
	CommonGUIFunctions:OnGUIOpen(player, npcModel)
end
function ShopGUI:OnGUIClose(player: Player)
	CommonGUIFunctions:OnGUIClose(player)
end
function ShopGUI:BuyRefillAmmo(player: Player)
	local human = PlayerManager:GetHumanClassFromPlayer(player)
	if not human then
		warn("Human missing, can't buy")
		return false
	end
	local currentGun = human.CurrentGun
	if not currentGun then
		warn("Can't refill ammo, human has no current gun")
		return false
	end

	if currentGun.GunName ~= "Revolver" then
		local currentMoney = ServerData.GetMoney(player)
		local moneyIfPurchased = currentMoney - ShopCosts.AmmoRefill
		if currentMoney and moneyIfPurchased < 0 then
			warn(`Can't afford ammo refill`)
			return false
		end
	end

	local maxStack = currentGun.MaxAmmo * currentGun.MaxAmmoStack
	if currentGun.AmmoReserve == maxStack then
		return false
	end

	currentGun:UpdateAmmoReserve(maxStack - currentGun.AmmoReserve)
	if currentGun.GunName ~= "Revolver" then
		ServerData.UpdateMoney(player, -ShopCosts.AmmoRefill)
	end
	return true
end
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
ShopGUI.networker = Networker.new(
	"ShopNetwork",
	ShopGUI,
	{ ShopGUI.BuyItem, ShopGUI.OnGUIClose, ShopGUI.OnGUIOpen, ShopGUI.BuyRefillAmmo }
)
return ShopGUI
