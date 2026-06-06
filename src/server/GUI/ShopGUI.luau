local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CommonGUIFunctions = require(script.Parent.CommonGUIFunctions)
local PopupGUI = require(script.Parent.PopupGUI)
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
	local gunData = GunData[currentGun.Name]
	if not currentGun or not gunData then
		warn("Can't refill ammo, human has no current gun ref or data")
		return false
	end
	local refillCost = GunData[currentGun.Name].RefillCost or 100
	if currentGun.Name ~= "Revolver" then
		local currentMoney = ServerData.GetMoney(player)

		local moneyIfPurchased = currentMoney - refillCost
		if currentMoney and moneyIfPurchased < 0 then
			warn(`Can't afford ammo refill`)
			PopupGUI:NewPopup(player, 1, `Can't afford refill`)
			return false
		end
	end

	local maxStack = currentGun.MaxAmmo * currentGun.MaxAmmoStack
	if currentGun.AmmoReserve == maxStack then
		PopupGUI:NewPopup(player, 1, `Already max ammo!`)
		return false
	end

	currentGun:UpdateAmmoReserve(maxStack - currentGun.AmmoReserve)
	if currentGun.Name ~= "Revolver" then
		ServerData.UpdateMoney(player, -refillCost)
	end

	PopupGUI:NewPopup(player, 1, `Refilled ammo`)
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
		PopupGUI:NewPopup(player, 1, `Can't afford {productName}`)
		return false
	end

	local currentGun = human.Inventory:GetGun()
	if GunData[productName] then
		if currentGun and currentGun.Name == productName then
			return false
		end
		human.Inventory:SwapWeapon(productName, "Gun")
		PopupGUI:NewPopup(player, 1, `Gun swapped to {productName}`)
	elseif ThrowableData[productName] then
		local currentThrowable = human.Inventory:GetThrowable()
		if currentThrowable then
			if currentThrowable.Name == productName then
				currentThrowable.CurrentAmmo += 1
				PopupGUI:NewPopup(player, 1, `Increased throwable ammo +1}`)
			else
				human.Inventory:SwapWeapon(productName, "Throwable")
				PopupGUI:NewPopup(player, 1, `Swapped throwable to {productName}`)
			end
		else
			PopupGUI:NewPopup(player, 1, `Bought {productName}`)
			human.Inventory:AddWeaponToInventory(productName, 1)
			human.Inventory:EquipWeapon("Throwable")
		end
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
