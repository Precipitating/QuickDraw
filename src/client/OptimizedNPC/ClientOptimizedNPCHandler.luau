local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local NPCTypesKeyed = require(ReplicatedStorage.Shared.NPCData.NPCs.NPCTypesKeyed)
local OptimizedNPCHandler = require(ReplicatedStorage.Shared.OptimizedNPC.OptimizedNPCHandler)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local NPCDataRemote = ReplicatedStorage.Shared.Remote.NPCDataRemote
local NPCFolder = ReplicatedStorage.Shared.NPCData.NPCs.Humans
local BanditModels = { "CowboyNPC" }
local SheriffModels = { "SheriffNPC" }
local MercenaryModels = { "MercenaryNPC" }
local Interpolations = {}

local ClientOptimizedNPCHandler = {}
local function InterpolatePart(part, startCFrame, endCFrame)
	Interpolations[part] = {
		startCF = startCFrame,
		endCF = endCFrame,
		elapsed = 0,
	}
end

local function GetNPCModel(spawnerType: number)
	if not spawnerType then
		warn("Spawner missing attribute SpawnerType")
		return nil
	end

	local key = NPCTypesKeyed[spawnerType]

	if key == "Bandit" then
		return NPCFolder:FindFirstChild(BanditModels[RandomModule.GetRandomIntBetween(1, #BanditModels)])
	elseif key == "Sheriff" then
		return NPCFolder:FindFirstChild(SheriffModels[RandomModule.GetRandomIntBetween(1, #SheriffModels)])
	elseif key == "Mercenary" then
		return NPCFolder:FindFirstChild(MercenaryModels[RandomModule.GetRandomIntBetween(1, #MercenaryModels)])
	else
		return nil
	end
end

local function UnpackEnemy(data)
	local unpacked = Sera.Deserialize(SeraSchemas.NPCSchema, data)

	local enemy = {}
	enemy.ID = unpacked.ID
	enemy.CFrame = unpacked.CFrame
	enemy.Faction = unpacked.Faction

	return enemy
end

local function onEnemyRender(packet)
	for _, entry in packet do
		local enemy = UnpackEnemy(entry)
		local targetCFrame = enemy.CFrame

		if not OptimizedNPCHandler.Enemies[enemy.ID] then
			local render = GetNPCModel(enemy.Faction):Clone()
			render.Parent = workspace.NPCs
			render.Name = enemy.ID
			OptimizedNPCHandler.Enemies[enemy.ID] = {}
			OptimizedNPCHandler.Enemies[enemy.ID].render = render
			OptimizedNPCHandler.Enemies[enemy.ID].currentCFrame = targetCFrame
			CollectionService:AddTag(render, "NPC")
			render:SetAttribute("Legless", false)

			local lowerTorso = render:WaitForChild("HumanoidRootPart", 2)
			if lowerTorso then
				lowerTorso.CFrame = targetCFrame
			end
		else
			local data = OptimizedNPCHandler.Enemies[enemy.ID]
			if data.render:FindFirstChild("HumanoidRootPart") then
				InterpolatePart(data.render.HumanoidRootPart, data.currentCFrame, targetCFrame)
			end
			data.currentCFrame = targetCFrame
		end
	end
end

function ClientOptimizedNPCHandler:Initialize()
	NPCDataRemote.OnClientEvent:Connect(onEnemyRender)

	RunService.RenderStepped:Connect(function(deltatime)
		for part, data in Interpolations do
			data.elapsed += deltatime
			local alpha = math.clamp(data.elapsed / 0.1, 0, 1)
			part.CFrame = data.startCF:Lerp(data.endCF, alpha)
			if alpha >= 1 then
				Interpolations[part] = nil
			end
		end
	end)
end

return ClientOptimizedNPCHandler
