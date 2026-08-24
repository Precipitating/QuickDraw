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

	npcRecord.configuration.motionSize = Vector3.new(6, 6, 6)
	npcRecord.configuration.maximumSlopeAngle = 50
	npcRecord.configuration.maximumStepHeight = 3
	npcRecord.currentPose = "idle"
end

function NPCPoses:ChangePose(npcRecord: LightweightNpcTypes.npcRecordType, poseName: string, channel: number?)
	if npcRecord.currentPose and npcRecord.currentPose == poseName then
		return
	end
	self:ResetPose(npcRecord)
	npcRecord.poses[poseName]:Play(0.5, 1, 1)
	npcRecord:PlayAnimation(poseName, false, channel or 1, 1)
	npcRecord.currentPose = poseName

	if poseName == "crawlidle" then
		npcRecord.configuration.maximumSlopeAngle = 10
		npcRecord.configuration.maximumStepHeight = 1
	end
end

return NPCPoses
