local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Queue = require(ReplicatedStorage.Shared.Classes.Queue)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local OptimizedNPCHandler = require(ReplicatedStorage.Shared.OptimizedNPC.OptimizedNPCHandler)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local NPCList = ReplicatedStorage.Shared.NPCData.NPCs.Humans
local TargetList = Queue.new()

local NPCDataRemote = ReplicatedStorage.Shared.Remote.NPCDataRemote
local Elapsed = 0
type HumanPlayer = ClassTypes.HumanPlayer

local NPCEvents = {}
NPCEvents.MaxNPCSAllowed = 30
NPCEvents.MaxNPCTypesAllowed = {
	Sheriff = 15,
	Bandit = 15,
}
NPCEvents.NPCTypesSpawned = {
	Sheriff = 0,
	Bandit = 0,
}

NPCEvents.ActiveHumanNPCS = {}
NPCEvents.SecondsToSpawnNPC = 120
NPCEvents.CurrentSpawnedNPCS = 0

-- Each NPC type can only spawn 3 above the rest of the types to prevent faction dominance
local MAX_TYPE_OFFSET = 3

-- Returns true if the specified NPC type has a spawn count exceeding another types by MAX_TYPE_OFFSET
local function IsNPCTypeOverloading(npcType: string)
	local currentTypeSpawnCount = NPCEvents.NPCTypesSpawned[npcType]

	for currNpcType, spawnCount in NPCEvents.NPCTypesSpawned do
		if currNpcType == npcType then
			continue
		end
		if (currentTypeSpawnCount - spawnCount) >= MAX_TYPE_OFFSET then
			return true
		end
	end

	return false
end

local function CanSpawn(spawnerType: string)
	if not spawnerType then
		return false
	end
	if NPCEvents.CurrentSpawnedNPCS >= NPCEvents.MaxNPCSAllowed then
		return false
	end

	if NPCEvents.NPCTypesSpawned[spawnerType] then
		local spawnedType = NPCEvents.NPCTypesSpawned[spawnerType]
		local maxAllowed = NPCEvents.MaxNPCTypesAllowed[spawnerType]
		if spawnedType == nil or maxAllowed == nil then
			return false
		end

		if IsNPCTypeOverloading(spawnerType) then
			return false
		end

		if spawnedType < maxAllowed then
			return true
		end
	end

	return false
end

local function AddHumanNPCClass(id: number, taggedNPC: Model, classType: string)
	local humanoid = taggedNPC:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error("NPC has no humanoid to initialize its class!")
	end

	local humanNPC = nil
	local factionType = nil
	-- Mercenary mode, will spawn at a random spawner
	if not TargetList:isEmpty() then
		local mercenaryTarget = TargetList:dequeue()
		factionType = "Mercenary"
		taggedNPC.Name = `Mercenary{NPCEvents.CurrentSpawnedNPCS}`
		CollectionService:AddTag(taggedNPC, "Mercenary")
		humanNPC = PlayerManager:AddHumanClassNPC(
			id,
			humanoid,
			"Grenadier",
			factionType,
			{ DefaultStateData = { Target = mercenaryTarget.Character } }
		)
		humanNPC.AI.EnemyList = { [mercenaryTarget.Name] = true }
	elseif CollectionService:HasTag(taggedNPC, "Sheriff") then
		factionType = "Sheriff"
		humanNPC = PlayerManager:AddHumanClassNPC(id, humanoid, classType, factionType)
		taggedNPC.Name = `Sheriff{NPCEvents.CurrentSpawnedNPCS}`
		humanNPC.AI.EnemyList = { Bandit = true, Wanted = true }
	else
		-- else Bandit
		factionType = "Bandit"
		humanNPC = PlayerManager:AddHumanClassNPC(id, humanoid, classType, factionType)
		humanNPC.AI.EnemyList = { Player = true, Sheriff = true, Animal = true }
	end

	print(`[SERVER] NPCs spawned: {NPCEvents.CurrentSpawnedNPCS}`)
	return humanNPC, factionType
end

local function SpawnLoop(spawnerModel, spawnLocation)
	if not spawnerModel or not spawnerModel.Parent then
		return
	end
	local npcType = nil
	for key, _ in NPCTypes do
		if CollectionService:HasTag(spawnerModel, key) then
			npcType = key
			break
		end
	end

	if not npcType then
		warn("Spawner has no matching NPC type tag:", spawnerModel.Name)
		task.delay(
			RandomModule.GetRandomIntBetween(1, 10) + NPCEvents.SecondsToSpawnNPC,
			SpawnLoop,
			spawnerModel,
			spawnLocation
		)
		return
	end

	-- Early exit conditions
	----------------------------------------------------------------------------------------
	if NPCEvents.CurrentSpawnedNPCS >= NPCEvents.MaxNPCSAllowed then
		task.delay(
			RandomModule.GetRandomIntBetween(1, 10) + NPCEvents.SecondsToSpawnNPC,
			SpawnLoop,
			spawnerModel,
			spawnLocation
		)
		return
	end

	local spawnerType = spawnerModel:GetAttribute("SpawnerType")
	if not CanSpawn(spawnerType) then
		task.delay(
			RandomModule.GetRandomIntBetween(1, 10) + NPCEvents.SecondsToSpawnNPC,
			SpawnLoop,
			spawnerModel,
			spawnLocation
		)
		return
	end

	-- local npcModel = GetNPCModel(spawnerType)
	-- if not npcModel then
	-- 	warn("Spawner has no valid npc model to choose from")
	-- 	task.delay(
	-- 		RandomModule.GetRandomIntBetween(1, 10) + NPCEvents.SecondsToSpawnNPC,
	-- 		SpawnLoop,
	-- 		spawnerModel,
	-- 		spawnLocation
	-- 	)
	-- 	return
	-- end
	----------------------------------------------------------------------------------------

	--npcModel = NPCList[npcModel]:Clone()

	-- 1. Spawn a basic rig on the server, let the client handle the apperance and visuals
	local npcClass = OptimizedNPCHandler.new(spawnLocation.WorldPosition)
	local npcModel = npcClass.Model

	if not npcModel then
		error("Model missing when spawning new enemy NPC")
		return
	end

	-- 1.1 Add relevant tags
	npcClass.Model.Name = `{npcType}NPC{NPCEvents.CurrentSpawnedNPCS}`
	CollectionService:AddTag(npcClass.Model, npcType)
	CollectionService:AddTag(npcClass.Model, spawnerType)
	CollectionService:AddTag(npcClass.Model, "NPC")

	-- 1.2 Set optional attribute (if exists) patrol paths ID
	if spawnerModel:GetAttribute("DefaultStateData") then
		npcClass.Model:SetAttribute("DefaultStateData", spawnerModel:GetAttribute("DefaultStateData"))
	end

	-- 2. Add the actual NPC class, handling AI, pathfinding and overall logic
	local _, faction = AddHumanNPCClass(npcClass.ID, npcClass.Model, npcType)

	-- 2.1 Used on client to spawn the correct NPC model appearance, this is a number to save network bandwith
	npcClass.Faction = faction

	-- 3. Update NPC spawned count
	NPCEvents.CurrentSpawnedNPCS = math.max(0, math.min(NPCEvents.CurrentSpawnedNPCS + 1, NPCEvents.MaxNPCSAllowed))
	if NPCEvents.NPCTypesSpawned[spawnerType] then
		NPCEvents.NPCTypesSpawned[spawnerType] =
			math.max(0, math.min(NPCEvents.NPCTypesSpawned[spawnerType] + 1, NPCEvents.MaxNPCTypesAllowed[spawnerType]))
	end

	task.delay(
		RandomModule.GetRandomIntBetween(1, 10) + NPCEvents.SecondsToSpawnNPC,
		SpawnLoop,
		spawnerModel,
		spawnLocation
	)
end

local function InitializeSpawner(spawnerModel)
	local spawnLocation: Attachment = spawnerModel:FindFirstChildOfClass("Attachment")
	if not spawnLocation then
		warn(`{spawnerModel.Name} has no attachment!`)
		return
	end

	SpawnLoop(spawnerModel, spawnLocation)
end

local function InitializeNPCSpawners()
	local spawnerInstances = CollectionService:GetTagged("Spawner")
	if #NPCList:GetChildren() <= 0 then
		error("NPC list has no children!")
	end

	for _, spawnerModel in spawnerInstances do
		InitializeSpawner(spawnerModel)
	end
end

-- For mercenaries: Next spawning NPC will only shoot the target
function NPCEvents.AddTarget(target: Player?)
	if not target then
		warn("Mercenary target invalid player instance")
		return
	end
	TargetList:enqueue(target)
end

function NPCEvents.Initialize()
	-- for dynamically spawned npcs
	-- CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(taggedNPC: Model)
	-- 	for key, _ in NPCTypes do
	-- 		if CollectionService:HasTag(taggedNPC, key) then
	-- 			AddNPCClass(taggedNPC, key)
	-- 			break
	-- 		end
	-- 	end
	-- end)

	CollectionService:GetInstanceAddedSignal("Spawner"):Connect(function(spawnerModel: Model)
		InitializeSpawner(spawnerModel)
	end)

	InitializeNPCSpawners()

	-- Update the NPCS on client at a a fixed rate
	RunService.Heartbeat:Connect(function(deltatime)
		Elapsed += deltatime
		if Elapsed >= 0.1 then
			Elapsed = 0
			NPCDataRemote:FireAllClients(OptimizedNPCHandler.ConstructRenderPacket())
		end
	end)
end

return NPCEvents
