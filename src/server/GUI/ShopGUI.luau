local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local CommonGUIFunctions = require(script.Parent.CommonGUIFunctions)
local PopupGUI = require(script.Parent.PopupGUI)
local ShopCosts = require(script.Parent.ShopCosts)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerData = require(ServerScriptService.Server.ServerData)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local HorseModel = ReplicatedStorage.Shared.NPCData.NPCs.RideableAnimals.HorseNPC
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

local function BuyConsumableWeapon(player: Player, human: ClassTypes.Human, productName: string, type: string)
	local currentItem = nil
	local success = true
	if type == "Throwable" then
		currentItem = human.Inventory:GetThrowable()
	elseif type == "Trap" then
		currentItem = human.Inventory:GetTrap()
	else
		warn("[BuyConsumableWeapon] UNKNOWN TYPE TO CONECT")
		return false
	end

	if currentItem then
		-- Already in inventory, increase its ammo instead by 1
		if currentItem.Name == productName then
			success = currentItem:UpdateAmmo(1)
			if success then
				PopupGUI:NewPopup(player, 1, `Increased {productName} ammo +1`)
			else
				PopupGUI:NewPopup(player, 1, `Cannot buy item, already max ammo`)
			end
			return success
		else
			success = human.Inventory:SwapWeapon(productName, type)
			PopupGUI:NewPopup(player, 1, `Swapped weapon to {productName}`)
		end
	else
		-- Not in inventory, add it.
		PopupGUI:NewPopup(player, 1, `Bought {productName}`)
		success = human.Inventory:AddWeaponToInventory(productName, 1)
		success = human.Inventory:EquipWeapon(type)
	end

	return success
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

	local success = true

	local currentGun = human.Inventory:GetGun()
	if GunData[productName] then
		if currentGun and currentGun.Name == productName then
			PopupGUI:NewPopup(player, 1, `You already own this weapon!`)
			return false
		end
		human.Inventory:SwapWeapon(productName, "Gun")
		PopupGUI:NewPopup(player, 1, `Gun swapped to {productName}`)
	elseif ThrowableData[productName] then
		success = BuyConsumableWeapon(player, human, productName, "Throwable")
	elseif TrapData[productName] then
		success = BuyConsumableWeapon(player, human, productName, "Trap")
	end

	if soundName then
		ServerSoundHandler:PlaySoundTo(player, soundName)
	end

	if productCost ~= 0 and success then
		ServerData.UpdateMoney(player, -productCost)
	end
	return success
end

function ShopGUI:BuyHorse(player: Player, horseType: string, horseSellerNPC: Model?)
	if not horseSellerNPC then
		return false
	end

	local currentMoney = ServerData.GetMoney(player)
	local moneyIfPurchased = currentMoney - ShopCosts[horseType]
	if currentMoney and moneyIfPurchased < 0 then
		PopupGUI:NewPopup(player, 1, `Can't afford {horseType}`)
		return false
	end

	local linkedStable = horseSellerNPC:GetAttribute("LinkedStable")
	linkedStable = linkedStable:Get()
	if not linkedStable then
		warn("Horse seller NPC has no linked stable")
		return false
	end
	local spawnPoints = linkedStable:FindFirstChild("SpawnPoints")
	if not spawnPoints then
		warn("Linked stable has no spawn points folder")
		return false
	end

	ServerData.UpdateMoney(player, -ShopCosts[horseType])

	spawnPoints = spawnPoints:GetChildren()
	local horseClone = HorseModel:Clone()

	local randomSpawnIdx = RandomModule.GetRandomIntBetween(1, #spawnPoints)
	horseClone:PivotTo(spawnPoints[randomSpawnIdx].WorldCFrame)
	horseClone:SetAttribute("HorseType", horseType)
	horseClone.Parent = workspace

	return true
end
ShopGUI.networker = Networker.new(
	"ShopNetwork",
	ShopGUI,
	{ ShopGUI.BuyItem, ShopGUI.OnGUIClose, ShopGUI.OnGUIOpen, ShopGUI.BuyRefillAmmo, ShopGUI.BuyHorse }
)
return ShopGUI
