local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local LootSpawner = {}
local MaxLootSpawnsAllowed = 10
local LootSpawnTime = 10
local LootSpawnAreas = ServerStorage.LootSpawnAreas:GetChildren()
local LootItems = ServerStorage.LootItems:GetChildren()
local CHECK_RADIUS = 5
local REPEAT_LIMIT = 10
local LootSpawnActive = true

local function GetRandomPositionInPart(part)
	local TopRightFront = part.Position + part.Size / 2
	local BottomLeftBack = part.Position - part.Size / 2

	local x = math.lerp(TopRightFront.X, BottomLeftBack.X, RandomModule.GetRandom())
	local y = math.lerp(TopRightFront.Y, BottomLeftBack.Y, RandomModule.GetRandom())
	local z = math.lerp(TopRightFront.Z, BottomLeftBack.Z, RandomModule.GetRandom())

	return Vector3.new(x, y, z)
end

function LootSpawner:IsPointClear(partSize: Vector3, pos: Vector3)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(pos), partSize)
	return #parts == 0
end

function LootSpawner:IsPositionSafe(partSize: Vector3, pos: Vector3)
	local partsAroundPosition = workspace:GetPartBoundsInRadius(pos, CHECK_RADIUS)

	for _, part in partsAroundPosition do
		if CollectionService:HasTag(part, "Loot") or part.Parent and part.Parent.Name == "EnvironmentProps" then
			return false
		end
	end

	if not self:IsPointClear(partSize, pos) then
		return false
	end

	return true
end

function LootSpawner:SpawnLoot()
	if #LootItems <= 0 or #LootSpawnAreas <= 0 then
		warn("Loot spawning missing spawn or item template")
		return
	end

	-- folder to store active loot on workspace
	local parentFolder = nil
	local lootFolder: Folder? = workspace:FindFirstChild("ActiveLoot")
	if not lootFolder then
		local folder = Instance.new("Folder")
		folder.Name = "ActiveLoot"
		parentFolder = folder
		folder.Parent = workspace
	else
		parentFolder = lootFolder
	end

	local activeLootCount = parentFolder and #parentFolder:GetChildren()
	if activeLootCount and activeLootCount >= MaxLootSpawnsAllowed then
		return
	end

	-- 1. Get random loot item mesh
	local lootItem: MeshPart = LootItems[RandomModule.GetRandomIntBetween(1, #LootItems)]
	if not lootItem then
		warn("Loot item missing")
		return
	end

	-- 2. Find a valid spot to spawn, repeat if it overlaps an existing loot spawn
	local repeatCount = 0
	local lootPos = nil
	repeat
		local newPos = LootSpawnAreas[RandomModule.GetRandomIntBetween(1, #LootSpawnAreas)]
		newPos = GetRandomPositionInPart(newPos)
		lootPos = newPos
		repeatCount += 1
	until self:IsPositionSafe(lootItem.ExtentsSize, newPos) or repeatCount >= REPEAT_LIMIT

	-- 3. Move to workspace and position
	lootItem = lootItem:Clone()
	lootItem:PivotTo(CFrame.new(lootPos))

	lootItem.Parent = parentFolder
end

function LootSpawner:StartLootSpawning()
	task.spawn(function()
		while LootSpawnActive do
			task.wait(LootSpawnTime)
			self:SpawnLoot()
		end
	end)
end

return LootSpawner
