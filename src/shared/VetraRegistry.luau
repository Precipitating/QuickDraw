local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralProjectilesData = require(script.Parent.GeneralProjectilesData)
local BehaviorRegistry = require(ReplicatedStorage.Shared.Vetra.VetraNet.Transport.BehaviorRegistry)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)

local Registry = BehaviorRegistry.new()

Registry:Register("Winchester", GunData["Winchester"].ProjectileData)
Registry:Register("Revolver", GunData["Revolver"].ProjectileData)
Registry:Register("Coach", GunData["Coach"].ProjectileData)
Registry:Register("RoperShotgun", GunData["RoperShotgun"].ProjectileData)
Registry:Register("CannonGun", GunData["CannonGun"].ProjectileData)
Registry:Register("Gatling", GunData["Gatling"].ProjectileData)

Registry:Register("Dynamite", ThrowableData["Dynamite"].ProjectileData)
Registry:Register("KetchumGrenade", ThrowableData["KetchumGrenade"].ProjectileData)
Registry:Register("Molotov", ThrowableData["Molotov"].ProjectileData)
Registry:Register("HookGrenade", ThrowableData["HookGrenade"].ProjectileData)

Registry:Register("Shrapnel", GeneralProjectilesData.Shrapnel.ProjectileData)

return Registry
