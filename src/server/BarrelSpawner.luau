local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local BarrelSpawner = {}
local BarrelLocationsArray = ServerStorage.Environment.BarrelLocations:GetChildren()
local BarrelLocations = ServerStorage.Environment.BarrelLocations
local Barrels = ServerStorage.Environment.Barrels
local BarrelsArray = Barrels:GetChildren()
local MAX_BARRELS_ALLOWED = 10
local SPAWN_RATE = 120 -- seconds
local CurrentBarrelsSpawned = 0
local Active = false
local MAX_TRIES = 10

function BarrelSpawner.SpawnBarrel(barrelName: string?, position: Vector3?)
	if CurrentBarrelsSpawned >= MAX_BARRELS_ALLOWED then
		return false
	end

	local barrelInstance = if barrelName and Barrels:FindFirstChild(barrelName)
		then Barrels:FindFirstChild(barrelName)
		else BarrelsArray[RandomModule.GetRandomIntBetween(1, #BarrelsArray)]

	local randomLocation = nil

	if not position then
		local tries = 0
		repeat
			randomLocation = BarrelLocationsArray[RandomModule.GetRandomIntBetween(1, #BarrelLocationsArray)]
			tries += 1
		until not randomLocation:GetAttribute("InUse")
			or randomLocation:GetAttribute("InUse") == false
			or tries >= MAX_TRIES

		if tries >= MAX_TRIES then
			return false
		end
	else
		randomLocation = position
	end

	if not barrelInstance or not randomLocation then
		warn("Can't spawn barrel, missing position or instance")
		return
	end

	barrelInstance = barrelInstance:Clone()
	if not position then
		barrelInstance:SetAttribute("SpawnLocationName", randomLocation.Name)
		randomLocation:SetAttribute("InUse", true)
		barrelInstance:PivotTo(CFrame.new(randomLocation.Position))
	else
		barrelInstance:PivotTo(CFrame.new(randomLocation))
	end
	barrelInstance.Parent = workspace.Destroyables or workspace

	return true
end

function BarrelSpawner.StartSpawnLoop()
	if Active then
		return
	end

	Active = true
	task.spawn(function()
		while Active do
			BarrelSpawner.SpawnBarrel()
			task.wait(SPAWN_RATE)
		end
	end)
end

-- Start server loop
function BarrelSpawner.Initialize()
	CollectionService:GetInstanceAddedSignal("Barrel"):Connect(function(barrel: Model)
		warn(`{barrel.Name} spawned`)
		CurrentBarrelsSpawned += 1
	end)

	CollectionService:GetInstanceRemovedSignal("Barrel"):Connect(function(barrel: Model)
		warn(`{barrel.Name} destroyed`)
		CurrentBarrelsSpawned -= 1
		local barrelSpawnLoc = barrel:GetAttribute("SpawnLocationName")
		if not barrelSpawnLoc then
			return
		end

		local spawnLoc = BarrelLocations:FindFirstChild(barrelSpawnLoc)

		if spawnLoc then
			spawnLoc:SetAttribute("InUse", false)
		end
	end)

	BarrelSpawner.StartSpawnLoop()
end

return BarrelSpawner
