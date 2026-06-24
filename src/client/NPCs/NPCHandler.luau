local CollectionService = game:GetService("CollectionService")

local NPCAnimationsHandler = require(script.Parent.Parent.Animations.NPCAnimationsHandler)
local NPCHandler = {}

function NPCHandler:InitializeNPCDialogue()
	local DialogueData = require(script.Parent.Parent.DialogueData)
	local dialogueNPCS = CollectionService:GetTagged("NPCPrompt")
	for _, npcPrompt in dialogueNPCS do
		local model = npcPrompt.Parent
		if not model then
			continue
		end
		local dialogueData = DialogueData[model.Name]
		if dialogueData then
			dialogueData(model, npcPrompt)
		end
	end
end
function NPCHandler:ConnectEvents()
	-- Initialize animation controller on NPCS that already exist on join
	local existingNPCS = CollectionService:GetTagged("NPC")

	for _, npc in existingNPCS do
		NPCAnimationsHandler:AddNPCAnimationController(npc)
	end

	-- initialize the animation controller per npc on dynamic add
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") then
			if CollectionService:HasTag(descendant, "NPC") then
				NPCAnimationsHandler:AddNPCAnimationController(descendant)
			end
		end
	end)

	workspace.DescendantRemoving:Connect(function(descendant: Instance)
		if descendant:IsA("Model") then
			if CollectionService:HasTag(descendant, "NPC") then
				NPCAnimationsHandler:RemoveNPCAnimationController(descendant)
			end
		end
	end)
end

function NPCHandler:Initialize()
	task.spawn(function()
		self:ConnectEvents()
		NPCAnimationsHandler:Initialize()
	end)
end

return NPCHandler
