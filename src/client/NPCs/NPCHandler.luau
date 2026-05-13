local CollectionService = game:GetService("CollectionService")
local NPCAnimationsHandler = require(script.Parent.Parent.Animations.NPCAnimationsHandler)
local NPCHandler = {}

function NPCHandler:ConnectEvents()
	-- Initialize animation controller on NPCS that already exist on join
	local existingNPCS = CollectionService:GetTagged("NPC")

	for _, npc in existingNPCS do
		NPCAnimationsHandler:AddNPCAnimationController(npc)
	end

	-- initialize the animation controller per npc on dynamic add
	workspace.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and CollectionService:HasTag(descendant, "NPC") then
			NPCAnimationsHandler:AddNPCAnimationController(descendant)
		end
	end)

	workspace.DescendantRemoving:Connect(function(descendant: Instance)
		if descendant:IsA("Model") and CollectionService:HasTag(descendant, "NPC") then
			NPCAnimationsHandler:RemoveNPCAnimationController(descendant)
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
