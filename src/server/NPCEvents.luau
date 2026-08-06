local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LightweightNPCModule = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
local Queue = require(ReplicatedStorage.Shared.Classes.Queue)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local NPCHealth = require(ServerScriptService.Server.LightweightNpcs.Code.NPCHealth)
local NPCLogic = require(ServerScriptService.Server.LightweightNpcs.Code.NPCLogic)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

local NPCModels = ReplicatedStorage.Shared.NPCData.NPCs.Humans
local NPCList = ReplicatedStorage.Shared.NPCData.NPCs.Humans

local BanditModels = { "CowboyNPC" }
local SheriffModels = { "SheriffNPC" }
local MercenaryModels = { "MercenaryNPC" }

local LightweightNPCConfig = LightweightNPCModule:CreateConfig()
local TargetList = Queue.new()

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

local MAX_TYPE_OFFSET = 3

local function IsNPCTypeOverloading(npcType: string): boolean
	local currentTypeSpawnCount = NPCEvents.NPCTypesSpawned[npcType] or 0

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

local function CanSpawn(spawnerType: string): boolean
	if not spawnerType then
		return false
	end
	if NPCEvents.CurrentSpawnedNPCS >= NPCEvents.MaxNPCSAllowed then
		return false
	end

	local spawnedType = NPCEvents.NPCTypesSpawned[spawnerType]
	local maxAllowed = NPCEvents.MaxNPCTypesAllowed[spawnerType]

	if not spawnedType or not maxAllowed then
		return false
	end
	if IsNPCTypeOverloading(spawnerType) then
		return false
	end

	return spawnedType < maxAllowed
end

local function AddHumanNPCClass(lightweightNPCClass, classType: string)
	local humanModel = lightweightNPCClass.instance
	local humanoid = humanModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("NPC has no humanoid! Ensure visuals/physics are handled correctly.")
	end

	local humanNPC = nil
	local factionType = nil

	if not TargetList:isEmpty() then
		local mercenaryTarget = TargetList:dequeue()
		factionType = "Mercenary"
		humanModel.Name = `Mercenary{NPCEvents.CurrentSpawnedNPCS}`
		CollectionService:AddTag(humanModel, "Mercenary")

		humanNPC = PlayerManager:AddHumanClassNPC(
			lightweightNPCClass,
			humanoid,
			"Grenadier",
			factionType,
			{ DefaultStateData = { Target = mercenaryTarget.Character } }
		)
		humanNPC.AI.EnemyList = { [mercenaryTarget.Name] = true }
	elseif CollectionService:HasTag(humanModel, "Sheriff") then
		factionType = "Sheriff"
		humanNPC = PlayerManager:AddHumanClassNPC(lightweightNPCClass, humanoid, classType, factionType)
		humanModel.Name = `Sheriff{NPCEvents.CurrentSpawnedNPCS}`
		humanNPC.AI.EnemyList = { Bandit = true, Wanted = true }
	else
		factionType = "Bandit"
		humanNPC = PlayerManager:AddHumanClassNPC(lightweightNPCClass, humanoid, classType, factionType)
		humanNPC.AI.EnemyList = { Player = true, Sheriff = true, Animal = true }
	end

	humanNPC.Faction = factionType

	return humanNPC
end

local function GetNPCModel(spawnerType: string)
	if spawnerType == "Bandit" then
		return NPCModels:FindFirstChild(BanditModels[RandomModule.GetRandomIntBetween(1, #BanditModels)])
	elseif spawnerType == "Sheriff" then
		return NPCModels:FindFirstChild(SheriffModels[RandomModule.GetRandomIntBetween(1, #SheriffModels)])
	elseif spawnerType == "Mercenary" then
		return NPCModels:FindFirstChild(MercenaryModels[RandomModule.GetRandomIntBetween(1, #MercenaryModels)])
	end
	return nil
end

local function SpawnNPCAtSpawner(spawnerModel, spawnLocation)
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
		return
	end
	if NPCEvents.CurrentSpawnedNPCS >= NPCEvents.MaxNPCSAllowed then
		return
	end

	local spawnerType = spawnerModel:GetAttribute("SpawnerType")
	if not CanSpawn(spawnerType) then
		return
	end

	local npcTemplateModel = GetNPCModel(spawnerType, spawnerModel:GetTags())
	if not npcTemplateModel then
		return
	end

	-- Spawn NPC
	local npcRecord = LightweightNPCModule:SpawnNpc(npcTemplateModel, LightweightNPCConfig, spawnLocation.WorldCFrame)
	local npcModel = npcRecord.instance
	npcRecord.data.nextMove = 0

	-- Main NPC logic goes here, syncs to client
	NPCLogic:OnSpawn(npcRecord)

	if not npcModel then
		return
	end

	npcModel.Name = `{npcType}NPC{NPCEvents.CurrentSpawnedNPCS}`
	npcModel:AddTag(npcType)
	npcModel:AddTag(spawnerType)
	npcModel:AddTag("NPC")

	if spawnerModel:GetAttribute("DefaultStateData") then
		npcModel:SetAttribute("DefaultStateData", spawnerModel:GetAttribute("DefaultStateData"))
	end

	--AddHumanNPCClass(npcClass, npcType)

	-- Update state counters
	NPCEvents.CurrentSpawnedNPCS = math.clamp(NPCEvents.CurrentSpawnedNPCS + 1, 0, NPCEvents.MaxNPCSAllowed)
	if NPCEvents.NPCTypesSpawned[spawnerType] then
		NPCEvents.NPCTypesSpawned[spawnerType] =
			math.clamp(NPCEvents.NPCTypesSpawned[spawnerType] + 1, 0, NPCEvents.MaxNPCTypesAllowed[spawnerType])
	end
end

local function InitializeSpawner(spawnerModel)
	local spawnLocation: Attachment = spawnerModel:FindFirstChildOfClass("Attachment")
	if not spawnLocation then
		return
	end

	-- Async wait per spawner
	task.wait(RandomModule.GetRandomIntBetween(1, 5))
	SpawnNPCAtSpawner(spawnerModel, spawnLocation)
end

local function InitializeNPCSpawners()
	local spawnerInstances = CollectionService:GetTagged("Spawner")
	if #NPCList:GetChildren() <= 0 then
		return
	end

	for _, spawnerModel in spawnerInstances do
		if spawnerModel:IsDescendantOf(workspace) then
			InitializeSpawner(spawnerModel)
		end
	end
end

function NPCEvents.AddTarget(target: Player?)
	if not target then
		return
	end
	TargetList:enqueue(target)
end

function NPCEvents.Initialize()
	task.spawn(function()
		while true do
			InitializeNPCSpawners()
			task.wait(NPCEvents.SecondsToSpawnNPC)
		end
	end)
end

return NPCEvents
