local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local AnimationHandler = {}
AnimationHandler.networker = Networker.new("AnimationNetwork", AnimationHandler)

-- setting default animation ids inside the Animate script
function AnimationHandler:SetAnimationFolder(player: Player, folderName: string)
	if player then
		self.networker:fire(player, "SetAnimationFolder", folderName)
	else
		self.networker:fireAll("SetAnimationFolder", folderName)
	end
end

function AnimationHandler.StopAllAnimationTracks(humanoid: Humanoid?)
	assert(humanoid, "[AnimationHandler.StopAllAnimationTracks] Missing humanoid")
	local animator: Animator? = humanoid:FindFirstChild("Animator") :: Animator?
	assert(animator, "[AnimationHandler.StopAllAnimationTracks] Animator missing from humanoid ")

	for _, v in pairs(animator:GetPlayingAnimationTracks()) do
		v:Stop()
	end
end

return AnimationHandler
