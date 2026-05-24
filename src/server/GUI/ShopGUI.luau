local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CommonGUIFunctions = require(script.Parent.CommonGUIFunctions)
local ShopCosts = require(script.Parent.ShopCosts)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerData = require(ServerScriptService.Server.ServerData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
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
	local currentGun = human.Inventory:GetGun()
	if not currentGun then
		warn("Can't refill ammo, human has no current gun")
		return false
	end

	if currentGun.Name ~= "Revolver" then
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
	if currentGun.Name ~= "Revolver" then
		ServerData.UpdateMoney(player, -ShopCosts.AmmoRefill)
	end
	return true
end
function ShopGUI:BuyItem(player: Player, productName: string, productCost: number, soundName: string?)
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

	local currentGun = human.Inventory:GetGun()
	if GunData[productName] then
		if currentGun and currentGun.Name == productName then
			return false
		end
		human.Inventory:SwapWeapon(productName, "Gun")
	elseif ThrowableData[productName] then
		human.Inventory:SwapWeapon(productName, "Throwable")
	end

	if soundName then
		ServerSoundHandler:PlaySoundTo(player, soundName)
	end

	if productCost ~= 0 then
		ServerData.UpdateMoney(player, -productCost)
	end
	return true
end
ShopGUI.networker = Networker.new(
	"ShopNetwork",
	ShopGUI,
	{ ShopGUI.BuyItem, ShopGUI.OnGUIClose, ShopGUI.OnGUIOpen, ShopGUI.BuyRefillAmmo }
)
return ShopGUI
