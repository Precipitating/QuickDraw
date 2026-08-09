local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
return {
	[GunsEnum.Revolver] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
	},
	[GunsEnum.Coach] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, -0.8, -0.8) * CFrame.Angles(math.rad(5), 0, 0),
	},
	[GunsEnum.Winchester] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, -0.5, 1) * CFrame.Angles(0, math.rad(-180), 0),
	},
	[GunsEnum.RoperShotgun] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, -0.8, -0.8) * CFrame.Angles(math.rad(5), 0, 0),
	},
	[GunsEnum.CannonGun] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, -0.8, -0.8) * CFrame.Angles(0, 0, 0),
	},

	[GunsEnum.Gatling] = {
		C0 = CFrame.new(0, -0.161, 0) * CFrame.Angles(math.rad(-90), 0, 0),
		C1 = CFrame.new(0, -0.5, -0.5) * CFrame.Angles(math.rad(5), 0, 0),
	},
}
