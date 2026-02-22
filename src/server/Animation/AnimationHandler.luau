local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local AnimationHandler = {}

-- setting default animation ids inside the Animate script
function AnimationHandler.SetAnimation(animation: Animation? | {}, id: string)
	assert(animation, "[AnimationHandler.SetAnimation] animation input is nil!")

	-- if table inputted, we'll loop and set all animations to same ID provided
	if typeof(animation) == "table" then
		for _, anim: Animation in pairs(animation) do
			if not anim:IsA("Animation") then
				continue
			end
			anim.AnimationId = id
		end
		return
	end

	animation.AnimationId = id
end

function AnimationHandler.StopAllAnimationTracks(humanoid: Humanoid?)
	assert(humanoid, "[AnimationHandler.StopAllAnimationTracks] Missing humanoid")
	local animator: Animator? = humanoid:FindFirstChild("Animator") :: Animator?
	assert(animator, "[AnimationHandler.StopAllAnimationTracks] Animator missing from humanoid ")

	for _, v in pairs(animator:GetPlayingAnimationTracks()) do
		v:Stop()
	end
end

AnimationHandler.networker = Networker.new("AnimationNetwork", AnimationHandler)
return AnimationHandler
