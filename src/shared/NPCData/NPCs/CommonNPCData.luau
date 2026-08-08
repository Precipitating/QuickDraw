local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
return {
	LIMB_HEALTH = {
		[LimbsEnum.Head] = 50,
		[LimbsEnum.UpperTorso] = 85,
		[LimbsEnum.LowerTorso] = 70,
		[LimbsEnum.LeftUpperArm] = 60,
		[LimbsEnum.LeftLowerArm] = 60,
		[LimbsEnum.RightUpperArm] = 60,
		[LimbsEnum.RightLowerArm] = 60,
		[LimbsEnum.RightHand] = 30,
		[LimbsEnum.LeftHand] = 30,
		[LimbsEnum.LeftUpperLeg] = 40,
		[LimbsEnum.LeftLowerLeg] = 40,
		[LimbsEnum.RightUpperLeg] = 40,
		[LimbsEnum.RightLowerLeg] = 40,
		[LimbsEnum.RightFoot] = 10,
		[LimbsEnum.LeftFoot] = 10,
	},

	DISMEMBER_ATTACHMENTS = {
		[LimbsEnum.LeftUpperArm] = "LeftShoulderRigAttachment",
		[LimbsEnum.LeftUpperLeg] = "LeftHipRigAttachment",
		[LimbsEnum.RightUpperLeg] = "RightHipRigAttachment",
		[LimbsEnum.Head] = "NeckRigAttachment",
	},
	DISMEMBER_LIMB_BLOOD_REQUIREMENT = {
		[LimbsEnum.LeftUpperArm] = true,
		[LimbsEnum.LeftUpperLeg] = true,
		[LimbsEnum.RightUpperLeg] = true,
		[LimbsEnum.Head] = true,
	},
	LIMB_CHAIN = {
		[LimbsEnum.LeftUpperLeg] = { LimbsEnum.LeftLowerLeg, LimbsEnum.LeftFoot },
		[LimbsEnum.LeftLowerLeg] = { LimbsEnum.LeftFoot },
		[LimbsEnum.RightUpperLeg] = { LimbsEnum.RightLowerLeg, LimbsEnum.RightFoot },
		[LimbsEnum.RightLowerLeg] = { LimbsEnum.RightFoot },
		[LimbsEnum.LeftUpperArm] = { LimbsEnum.LeftLowerArm, LimbsEnum.LeftHand },
		[LimbsEnum.LeftLowerArm] = { LimbsEnum.LeftHand },
		[LimbsEnum.RightUpperArm] = { LimbsEnum.RightLowerArm, LimbsEnum.RightHand },
		[LimbsEnum.RightLowerArm] = { LimbsEnum.RightHand },
	},

	CRAWL_LIMB_REQUIREMENTS = {
		LimbsEnum.LeftUpperLeg,
		LimbsEnum.LeftLowerLeg,
		LimbsEnum.RightUpperLeg,
		LimbsEnum.RightLowerLeg,
	},

	SAFE_LIMBS_FROM_DISMEMBERING = {
		[LimbsEnum.UpperTorso] = true,
		[LimbsEnum.LowerTorso] = true,
		[LimbsEnum.RightHand] = true,
		[LimbsEnum.RightLowerArm] = true,
		[LimbsEnum.RightUpperArm] = true,
	},

	SAFE_LIMBS_FROM_DISABLING = {
		[LimbsEnum.Head] = true,
		[LimbsEnum.UpperTorso] = true,
		[LimbsEnum.LowerTorso] = true,
		[LimbsEnum.RightHand] = true,
		[LimbsEnum.RightLowerArm] = true,
		[LimbsEnum.RightUpperArm] = true,
		[LimbsEnum.RightFoot] = true,
		[LimbsEnum.LeftFoot] = true,
	},

	CRUCIAL_LIMBS = {
		[LimbsEnum.Head] = true,
		[LimbsEnum.UpperTorso] = true,
		[LimbsEnum.LowerTorso] = true,
	},

	BALL_SOCKET_MAX_FRICTION_TORQUES = {
		[LimbsEnum.LeftHand] = 16.976,

		[LimbsEnum.LeftFoot] = 26.867,

		[LimbsEnum.LeftLowerLeg] = 71.363,
		[LimbsEnum.LeftUpperLeg] = 25.812,

		[LimbsEnum.LeftLowerArm] = 58.609,
		[LimbsEnum.LeftUpperArm] = 50.275,

		[LimbsEnum.RightHand] = 16.976,

		[LimbsEnum.RightFoot] = 26.867,

		[LimbsEnum.RightLowerLeg] = 71.363,
		[LimbsEnum.RightUpperLeg] = 25.812,

		[LimbsEnum.RightLowerArm] = 58.609,
		[LimbsEnum.RightUpperArm] = 50.275,
	},
}
