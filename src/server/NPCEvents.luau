local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local NPCList = ServerStorage.NPCs:GetChildren()

type HumanPlayer = ClassTypes.HumanPlayer

local NPCEvents = {}
NPCEvents.MaxNPCSAllowed = 10
NPCEvents.SecondsToSpawnNPC = 300
NPCEvents.CurrentSpawnedNPCS = 0

local function AddNPCClass(taggedNPC: Model, classType: string)
	local humanoid = taggedNPC:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error("NPC has no humanoid to initialize its class!")
	end
	local humanNPC = PlayerManager:AddHumanClassNPC(humanoid, classType)

	NPCEvents.CurrentSpawnedNPCS += 1

	print(NPCEvents.CurrentSpawnedNPCS)

	return humanNPC
end

-- for existing models in studio, initialize its class
local function InitializeNPCS()
	local npcInstances = CollectionService:GetTagged("NPC")
	for _, NPC: Model in npcInstances do
		for _, NPCType: string in { "Sniper", "Basic" } do
			if CollectionService:HasTag(NPC, NPCType) then
				AddNPCClass(NPC, NPCType)
				break
			end
		end
	end
end

local function InitializeSpawner(spawnerModel)
	local spawnLocation: Attachment = spawnerModel:FindFirstChildOfClass("Attachment")
	if not spawnLocation then
		warn(`{spawnerModel.Name} has no attachment!`)
		return
	end

	task.spawn(function()
		while spawnerModel do
			task.wait(NPCEvents.SecondsToSpawnNPC)
			if not spawnerModel then
				return
			end
			if NPCEvents.CurrentSpawnedNPCS >= NPCEvents.MaxNPCSAllowed then
				continue
			end

			local npcModel: Model = NPCList[RandomModule.GetRandomIntBetween(1, #NPCList)]:Clone()
			-- determine NPC type to spawn
			local npcType = nil
			for key, _ in NPCTypes do
				if CollectionService:HasTag(spawnerModel, key) then
					npcType = key
					break
				end
			end
			CollectionService:AddTag(npcModel, npcType)

			-- Instance added signal will add the NPC class after this tag is added
			CollectionService:AddTag(npcModel, "NPC")
			npcModel:PivotTo(spawnLocation.WorldCFrame)
			npcModel.Parent = workspace.NPCs
		end
	end)
end

local function InitializeNPCSpawners()
	local spawnerInstances = CollectionService:GetTagged("Spawner")
	if #NPCList <= 0 then
		error("NPC list has no children!")
	end

	for _, spawnerModel in spawnerInstances do
		InitializeSpawner(spawnerModel)
	end
end

function NPCEvents.Initialize()
	-- for dynamically spawned npcs
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(taggedNPC: Model)
		for key, _ in NPCTypes do
			if CollectionService:HasTag(taggedNPC, key) then
				AddNPCClass(taggedNPC, key)
				break
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("Spawner"):Connect(function(spawnerModel: Model)
		InitializeSpawner(spawnerModel)
	end)

	InitializeNPCS()
	InitializeNPCSpawners()
end

return NPCEvents
