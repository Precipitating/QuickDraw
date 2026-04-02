local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)
local AnimationSignals = require(script.Parent.AnimationSignals)
return {
	AnimationSignals.ChangeAnimationFolder:Connect(function(folderName: string)
		local folder = ReplicatedStorage.Shared.AnimationData:WaitForChild(folderName, 10)
		if not folder then
			warn("Animation folder name not found")
			return
		end
		PlayerContext.AnimationController:ChangeAllAnimations(folderName)
	end),
}
