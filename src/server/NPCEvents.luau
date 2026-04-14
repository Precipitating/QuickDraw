local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type HumanPlayer = ClassTypes.HumanPlayer

local function AddNPCClass(taggedNPC: Model, classType: string)
	local humanoid = taggedNPC:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error("NPC has no humanoid to initialize its class!")
	end
	local humanNPC = PlayerManager:AddHumanClassNPC(humanoid, classType)

	return humanNPC
end

-- for existing models in studio, initialize its class
local function Initialize()
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

return {
	Initialize(),

	-- for dynamically spawned npcs
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(taggedNPC: Model)
		for _, NPCType: string in { "Sniper", "Basic" } do
			if CollectionService:HasTag(taggedNPC, NPCType) then
				AddNPCClass(taggedNPC, NPCType)
				break
			end
		end
	end),
}
