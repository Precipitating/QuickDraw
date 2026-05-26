local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local AnimationSignals = require(script.Parent.AnimationSignals)
local NPCAnimationsHandler = require(script.Parent.NPCAnimationsHandler)
return {
	AnimationSignals.ChangeAnimationFolder:Connect(function(folderName: string, characterModel: Model?)
		if not PlayerContext or not PlayerContext.AnimationController then
			return
		end
		local folder = ReplicatedStorage.Shared.AnimationData:WaitForChild(folderName, 10)
		if not folder then
			warn("Animation folder name not found")
			return
		end
		-- means this is for NPC
		if characterModel then
			local npcAnimationController = NPCAnimationsHandler:GetNPCAnimations(characterModel)
			if not npcAnimationController then
				warn(`[ChangeAnimationFolder] No animation controller found for`, characterModel.Name)
				return
			end
			npcAnimationController:ChangeAllAnimations(folder)
		else
			PlayerContext.AnimationController:ChangeAllAnimations(folder)
		end
	end),
	AnimationSignals.ResetToDefaultAnimations:Connect(function(characterModel: Model?)
		-- means this is for NPC
		if characterModel then
			local npcAnimationController = NPCAnimationsHandler:GetNPCAnimations(characterModel)
			if not npcAnimationController then
				warn(`[ResetToDefaultAnimations] No animation controller found for`, characterModel.Name)
				return
			end
			npcAnimationController:ResetToDefaultAnimations()
		else
			PlayerContext.AnimationController:ResetToDefaultAnimations()
		end
	end),
}
