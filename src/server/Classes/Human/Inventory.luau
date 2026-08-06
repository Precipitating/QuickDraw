local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local HumanTypeEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.HumanTypeEnum)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local Gun = require(ServerScriptService.Server.Classes.Gun.Gun)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local ThrowableSignals = require(ServerScriptService.Server.Classes.Throwable.ThrowableSignals)
local Trap = require(ServerScriptService.Server.Classes.Trap.Trap)
local TrapSignals = require(ServerScriptService.Server.Classes.Trap.TrapSignals)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local WeaponTools = ReplicatedStorage.Shared.Templates
type Human = ClassTypes.Human
type Inventory = ClassTypes.Inventory

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(owner: Human): Inventory
	local self = setmetatable({}, Inventory)
	self.Owner = owner
	self.Items = {} -- Name - {Quantity, BaseWeight}
	self.MaxSlots = 10
	self.OccupiedSlots = 0

	-- Should store the CLASS of the weapon
	self.StoredWeapons = {
		Gun = nil,
		Throwable = nil,
		Trap = nil,
	}

	-- boolean state if weapon in inventory, not actually holding
	self.EquippedWeapons = {
		Gun = false,
		Throwable = false,
		Trap = false,
	}

	return self
end

function Inventory:Destroy()
	for weaponType, weapon in pairs(self.StoredWeapons) do
		if weapon and type(weapon.Destroy) == "function" then
			weapon:Destroy()
		end
	end
	table.clear(self.StoredWeapons)
	table.clear(self.EquippedWeapons)
	table.clear(self.Items)
	setmetatable(self, nil)
	table.clear(self)
end
function Inventory:IsEquippingWeapon(weaponType: string)
	local character = self.Owner and self.Owner.Character
	local currentWeapon = self.StoredWeapons[weaponType]

	if not character or not currentWeapon then
		return false
	end

	return character:FindFirstChild(currentWeapon.Name) ~= nil
end

function Inventory:RemoveWeapon(weaponType: string)
	local storedWeapon = self.StoredWeapons[weaponType]
	local character = self.Owner and self.Owner.Character
	local humanoid = self.Owner and self.Owner.Humanoid

	if not storedWeapon or not character or not humanoid then
		warn("[Inventory:RemoveThrowable] Missing throwable, character, or humanoid")
		return false
	end

	if self.Owner.HumanType == HumanTypeEnum.Player then
		local backpack = self.Owner.Player:FindFirstChild("Backpack")
		if not backpack then
			warn("[Inventory:RemoveWeapon] Missing backpack")
			return false
		end

		if self:IsEquippingWeapon(weaponType) then
			humanoid:UnequipTools()
		end

		storedWeapon:Destroy()
	elseif self.Owner.HumanType == "NPC" then
		storedWeapon:Destroy()
	end

	self.OccupiedSlots = math.min(math.max(0, self.OccupiedSlots - 1), self.MaxSlots)
	self.StoredWeapons[weaponType] = nil
	self.EquippedWeapons[weaponType] = false
	return true
end

function Inventory:CanEquip()
	local bodyParts = self.Owner.BodyParts
	local disabledBodyParts = self.Owner.DisabledBodyParts
	if not bodyParts then
		warn("Missing bodyparts reference, cannot equip gun!")
		return false
	end

	-- Ensure the right arm exists
	if not bodyParts.RightUpperArm or not bodyParts.RightLowerArm or not bodyParts.RightHand then
		warn("Right arm is gone, cannot equip gun!")
		return false
	end

	-- Ensure the right arm is not disabled
	if disabledBodyParts["RightUpperArm"] or disabledBodyParts["RightLowerArm"] or disabledBodyParts["RightHand"] then
		warn("Right arm is disabled, cannot equip gun!")
		return false
	end

	return true
end

function Inventory:SwapWeapon(newWeaponName: string, weaponType: string)
	local weaponRemoved = self:RemoveWeapon(weaponType)
	local weaponAdded = self:AddWeaponToInventory(newWeaponName)
	local equipWeapon = self:EquipWeapon(weaponType)
	return weaponRemoved and weaponAdded and equipWeapon
end

function Inventory:EquipWeapon(weaponType: string)
	if not self:CanEquip() then
		return false
	end
	local weapon = self.StoredWeapons[weaponType]
	if not weapon then
		warn("Weapon not in inventory")
		return false
	end
	local ownerType = self.Owner and self.Owner.HumanType
	if not ownerType then
		warn("[Inventory:EquipWeapon] Failed to get owner type")
		return false
	end

	if ownerType == HumanTypeEnum.Player then
		local player = self.Owner.Player
		local backpack = player.Backpack
		weapon.Tool.Parent = backpack

		if weaponType == "Gun" then
			GunSignals.ConnectGunSignal:Fire(self.Owner.Player, weapon.Tool)
			weapon:InitializeAmmoValues()
		elseif weaponType == "Throwable" then
			--weapon.RaycastParams.ExcludeInstances = { weapon.Tool }
			ThrowableSignals.ConnectThrowableSignal:Fire(self.Owner.Player, weapon.Tool)
		elseif weaponType == "Trap" then
			TrapSignals.ConnectTrapSignal:Fire(self.Owner.Player, weapon.Tool)
		end
	elseif ownerType == "NPC" then
		local character = self.Owner.Character
		local tool = weapon.Tool
		weapon:ToggleCollision(false)
		tool.Parent = character
		weapon:InitializeAmmoValues()
	else
		warn("Can't equip weapon, invalid human type")
		return false
	end

	self.EquippedWeapons[weaponType] = true
	return true
end

-- Just stores to inventory, nothing will occur physically
function Inventory:AddWeaponToInventory(name: string, quantity: number?, maxQuantity: number?)
	if self:IsFull() then
		warn(`Inventory full, can't add {name}`)
		return false
	end

	local weaponClone = WeaponTools:FindFirstChild(name, true)
	if not weaponClone then
		warn("[Inventory:EquipWeapon] Can't equip weapon, template doesnt exist")
		return false
	end
	weaponClone = weaponClone:Clone()

	if GunData[name] then
		if self.StoredWeapons["Gun"] then
			self:RemoveWeapon("Gun")
		end
		self.StoredWeapons["Gun"] = Gun.new(name, self.Owner, self.Owner.Player or self.Owner.Character, weaponClone)
		self.StoredWeapons["Gun"].Janitor:Add(weaponClone)
	elseif ThrowableData[name] then
		if self.StoredWeapons["Throwable"] then
			self:RemoveWeapon("Throwable")
		end
		self.StoredWeapons["Throwable"] = Throwable.new(name, self.Owner, quantity, maxQuantity, weaponClone)
		self.StoredWeapons["Throwable"].Janitor:Add(weaponClone)
	elseif TrapData[name] then
		if self.StoredWeapons["Trap"] then
			self:RemoveWeapon("Trap")
		end

		self.StoredWeapons["Trap"] = Trap.new(name, self.Owner, quantity, weaponClone)
		self.StoredWeapons["Trap"].Janitor:Add(weaponClone)
	else
		warn(`{name} is an invalid weapon to add to inventory!`)
		return false
	end

	self.OccupiedSlots = math.min(self.OccupiedSlots + 1, self.MaxSlots)
	return true
end

function Inventory:AddItem(name: string, amount: number?, itemWeight: number?): boolean
	local items = self.Items
	if not items then
		warn("Cannot add item to inventory, items table missing")
		return false
	end

	-- Safeguard inputs
	local amountToAdd = amount or 1
	local singleItemWeight = itemWeight or 1

	-- If the item already exists, we should rely on its established BaseWeight
	if items[name] then
		singleItemWeight = items[name].BaseWeight
	end

	local totalTransactionWeight = amountToAdd * singleItemWeight

	-- Capacity Check
	if self:IsFull() or self:GetAvailableSlotCount() < totalTransactionWeight then
		warn("Not enough available slots, can't pickup")
		-- Make sure PopupGUI exists on the server or use a RemoteEvent here!
		if PopupGUI and self.Owner and self.Owner.Player then
			PopupGUI:NewPopup(self.Owner.Player, 2, "Not enough inventory space to pickup!")
		end
		return false
	end

	if items[name] then
		-- Update existing stack
		items[name].Quantity += amountToAdd
	else
		items[name] = {
			Quantity = amountToAdd,
			BaseWeight = singleItemWeight,
		}
	end

	self.OccupiedSlots = math.clamp(self.OccupiedSlots + totalTransactionWeight, 0, self.MaxSlots)

	return true
end

function Inventory:RemoveItem(name: string, amount: number?): boolean
	local items = self.Items
	if not items or not items[name] then
		return false
	end

	local itemData = items[name]

	-- If amount is provided
	local amountToRemove = amount and math.min(amount, itemData.Quantity) or itemData.Quantity

	-- Calculate total weight/slots to remove for this transaction
	local weightToRemove = amountToRemove * itemData.BaseWeight

	-- Update OccupiedSlots cleanly (clamped between 0 and MaxSlots)
	self.OccupiedSlots = math.clamp(self.OccupiedSlots - weightToRemove, 0, self.MaxSlots)

	-- Update item quantities
	itemData.Quantity -= amountToRemove

	-- Completely wipe the item from the dictionary if the stack is empty
	if itemData.Quantity <= 0 then
		items[name] = nil
	end

	return true
end
function Inventory:GetAvailableSlotCount()
	return self.MaxSlots - self.OccupiedSlots
end
function Inventory:GetMaxSlotCount()
	return self.MaxSlots
end

function Inventory:GetStoredItems()
	return self.Items
end
function Inventory:GetGun()
	return self.StoredWeapons["Gun"]
end
function Inventory:GetThrowable()
	return self.StoredWeapons["Throwable"]
end
function Inventory:GetTrap()
	return self.StoredWeapons["Trap"]
end
function Inventory:GetOccupiedSlotCount()
	return self.OccupiedSlots
end
function Inventory:IsFull()
	return self.OccupiedSlots >= self.MaxSlots
end

return Inventory
