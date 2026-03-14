local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type HumanPlayer = ClassTypes.HumanPlayer

local function AddNPCClass(taggedNPC: Model)
	local humanoid = taggedNPC:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error("NPC has no humanoid to initialize its class!")
	end
	local humanNPC = PlayerManager:AddHumanClassNPC(humanoid)

	-- ragdoll
	humanoid.Died:Connect(function()
		humanNPC:OnDeath()
	end)

	return humanNPC
end

-- for existing models in studio, initialize its class
local function Initialize()
	local npcInstances = CollectionService:GetTagged("NPC")

	for _, NPC: Model in ipairs(npcInstances) do
		local npc = AddNPCClass(NPC)
		npc:AttackPlayer(workspace:WaitForChild("oOR0B0TOo"))
	end
end

return {
	Initialize(),

	-- for dynamically spawned npcs
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function(taggedNPC: Model)
		AddNPCClass(taggedNPC)
	end),
}
