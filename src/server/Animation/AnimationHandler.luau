local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local AnimationHandler = {}
AnimationHandler.networker = Networker.new("AnimationNetwork", AnimationHandler)

-- setting default animation ids inside the Animate script
function AnimationHandler:SetAnimationFolder(player: Player?, folderName: string, characterModel: Model?)
	if player and not characterModel then
		self.networker:fire(player, "SetAnimationFolder", folderName, nil)
	else
		-- character model as NPCAnimationsHandler stores NPC animations using the model as key
		self.networker:fireAll("SetAnimationFolder", folderName, characterModel)
	end
end

function AnimationHandler.StopAllAnimationTracks(humanoid: Humanoid?)
	assert(humanoid, "[AnimationHandler.StopAllAnimationTracks] Missing humanoid")
	local animator: Animator? = humanoid:FindFirstChild("Animator") :: Animator?
	assert(animator, "[AnimationHandler.StopAllAnimationTracks] Animator missing from humanoid ")

	for _, v in animator:GetPlayingAnimationTracks() do
		v:Stop()
	end
end

return AnimationHandler
