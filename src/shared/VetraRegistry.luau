local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BehaviorRegistry = require(ReplicatedStorage.Shared.Vetra.VetraNet.Transport.BehaviorRegistry)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)

local Registry = BehaviorRegistry.new()

Registry:Register("Winchester", GunData["Winchester"].ProjectileData)
Registry:Register("Revolver", GunData["Revolver"].ProjectileData)
Registry:Register("Coach", GunData["Coach"].ProjectileData)

Registry:Register("Dynamite", ThrowableData["Dynamite"].ProjectileData)
Registry:Register("KetchumGrenade", ThrowableData["KetchumGrenade"].ProjectileData)
Registry:Register("Molotov", ThrowableData["Molotov"].ProjectileData)

return Registry
