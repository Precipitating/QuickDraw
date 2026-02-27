local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ColorCorrection: ColorCorrectionEffect = Lighting:WaitForChild("ColorCorrection")
local HumanNetwork = {}
HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork)

function HumanNetwork:RagdollClient()
	PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
end

function HumanNetwork:AdjustGrayscale(saturationTarget: number)
	ColorCorrection.Saturation = saturationTarget
end
return HumanNetwork
