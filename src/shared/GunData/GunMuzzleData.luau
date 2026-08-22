local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.GunsEnum)
-- Muzzle point attachment local CFrames
return {
	[GunsEnum.Revolver] = CFrame.new(-3.327, 0.634, 0) * CFrame.Angles(0, math.rad(90), 0),

	[GunsEnum.Coach] = CFrame.new(0, 0.265, -4.074) * CFrame.Angles(0, math.rad(90), 0),

	[GunsEnum.Winchester] = CFrame.new(0.045, 0.43, 6.065) * CFrame.Angles(0, math.rad(-90), 0),

	[GunsEnum.RoperShotgun] = CFrame.new(0, 0.353, -4.573) * CFrame.Angles(0, math.rad(90), 0),

	[GunsEnum.CannonGun] = CFrame.new(0, 0.548, -0.751) * CFrame.Angles(0, math.rad(90), 0),

	[GunsEnum.Gatling] = CFrame.new(0.005, 0.333, -3.316) * CFrame.Angles(0, math.rad(90), 0),
}
