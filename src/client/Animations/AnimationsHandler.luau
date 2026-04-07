local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationSignals = require(script.Parent.AnimationSignals)
local AnimationIds = require(ReplicatedStorage.Shared.AnimationData.AnimationIds)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local AnimationsHandler = {}
AnimationsHandler.networker = Networker.new("AnimationNetwork", AnimationsHandler)

-- [animation name] = [Animation]
local LoadedAnimations = {
	Roll = true,
	Kick = true,
}

function AnimationsHandler.LoadCustomAnimations(humanoid: Humanoid?)
	assert(humanoid, "Humanoid is nil loading custom animations!")
	local animator: Animator = Utility.GetInstance(humanoid, true, "Animator")

	for key, _ in LoadedAnimations do
		local loadedAnim: Animation = Instance.new("Animation")
		loadedAnim.AnimationId = `rbxassetid://{AnimationIds[key]}`
		LoadedAnimations[key] = animator:LoadAnimation(loadedAnim)
		print(`Loaded {key} animation`)
	end
end

function AnimationsHandler.PlayCustomAnimation(name: string)
	local animationInstance = LoadedAnimations[name]
	if not animationInstance then
		warn(`Can't play custom animation {name}, missing from table`)
		return
	end

	animationInstance:Play()

	return animationInstance
end

function AnimationsHandler:SetAnimationFolder(folderName: string, characterModel: Model?)
	AnimationSignals.ChangeAnimationFolder:Fire(folderName, characterModel)
end

function AnimationsHandler.StopCustomAnimation(name: string)
	local animationInstance = LoadedAnimations[name]
	if not animationInstance then
		warn(`Can't stop custom animation {name}, missing from table`)
		return
	end

	animationInstance:Stop()
end

return AnimationsHandler
