local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightweightNpcTypes = require(script.Parent.Parent.Parent.LightweightNpcs.Code.LightweightNpcTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local NPCPoses = {}

function NPCPoses:ResetPose(npcRecord: LightweightNpcTypes.npcRecordType)
	if not npcRecord.animator then
		Utility.Warn("Missing server NPC animator ref")
		return
	end

	local animator: Animator = npcRecord.animator

	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.1)
	end

	npcRecord.configuration.motionSize = Vector3.new(3, 6, 3)
	npcRecord.configuration.maximumSlopeAngle = 50
	npcRecord.configuration.maximumStepHeight = 3
end

function NPCPoses:ChangePose(npcRecord: LightweightNpcTypes.npcRecordType, poseName: string)
	self:ResetPose(npcRecord)
	npcRecord.poses[poseName]:Play(0.5, 1, 1)
	npcRecord:PlayAnimation(poseName, false, 1, 1)

	if poseName == "crawlidle" then
		npcRecord.configuration.maximumSlopeAngle = 10
		npcRecord.configuration.maximumStepHeight = 1
	end
end

return NPCPoses
