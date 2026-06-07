local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local Gun = require(ServerScriptService.Server.Classes.Gun.Gun)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local ThrowableSignals = require(ServerScriptService.Server.Classes.Throwable.ThrowableSignals)
local WeaponTools = ReplicatedStorage.Shared.Templates
type Human = ClassTypes.Human
type Inventory = ClassTypes.Inventory

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(owner: Human): Inventory
	local self = setmetatable({}, Inventory)
	self.Owner = owner
	self.Items = {} -- Name - Quantity
	self.MaxSlots = 10
	self.OccupiedSlots = 0

	-- Should store the CLASS of the weapon
	self.StoredWeapons = {
		Gun = nil,
		Throwable = nil,
	}

	-- boolean state if weapon in inventory, not actually holding
	self.EquippedWeapons = {
		Gun = false,
		Throwable = false,
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

	if self.Owner.HumanType == "Player" then
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
		return
	end
	local weapon = self.StoredWeapons[weaponType]
	if not weapon then
		warn("Weapon not in inventory")
		return false
	end
	local ownerType = self.Owner and self.Owner.HumanType
	if not ownerType then
		warn("[Inventory:EquipWeapon] Failed to get owner type")
		return
	end

	if ownerType == "Player" then
		local player = self.Owner.Player
		local backpack = player.Backpack
		weapon.Tool.Parent = backpack

		if weaponType == "Gun" then
			GunSignals.ConnectGunSignal:Fire(self.Owner.Player, weapon.Tool)
			weapon:InitializeAmmoValues()
		elseif weaponType == "Throwable" then
			weapon.RaycastParams.ExcludeInstances = { weapon.Tool }
			ThrowableSignals.ConnectThrowableSignal:Fire(self.Owner.Player, weapon.Tool)
		end
	elseif ownerType == "NPC" then
		local character = self.Owner.Character
		local tool = weapon.Tool

		weapon:ToggleCollision(false)
		tool.Parent = character
	else
		warn("Can't equip weapon, invalid human type")
		return false
	end

	self.EquippedWeapons[weaponType] = true
	return true
end

-- Just stores to inventory, nothing will occur physically
function Inventory:AddWeaponToInventory(name: string, quantity: number?)
	if self:IsFull() then
		warn(`Inventory full, can't add {name}`)
		return false
	end

	local weaponClone = WeaponTools:FindFirstChild(name)
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
		self.StoredWeapons["Throwable"] = Throwable.new(name, self.Owner, quantity, weaponClone)
		self.StoredWeapons["Throwable"].Janitor:Add(weaponClone)
	else
		warn(`{name} is an invalid weapon to add to inventory!`)
		return false
	end

	self.OccupiedSlots = math.min(self.OccupiedSlots + 1, self.MaxSlots)
	return true
end

function Inventory:GetAvailableSlotCount()
	return self.MaxSlots - self.OccupiedSlots
end
function Inventory:GetMaxSlotCount()
	return self.MaxSlots
end
function Inventory:GetGun()
	return self.StoredWeapons["Gun"]
end
function Inventory:GetThrowable()
	return self.StoredWeapons["Throwable"]
end
function Inventory:GetOccupiedSlotCount()
	return self.OccupiedSlots
end
function Inventory:IsFull()
	return self.OccupiedSlots >= self.MaxSlots
end

return Inventory
