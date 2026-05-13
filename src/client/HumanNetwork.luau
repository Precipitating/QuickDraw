local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inputs = require(script.Parent.ClientInputs.Inputs)
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ColorCorrection: ColorCorrectionEffect = Lighting:WaitForChild("ColorCorrection")
local HumanNetwork = {}
HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork)

function HumanNetwork:RagdollClient(ragdollTime: number)
	if not PlayerContext.Humanoid then
		warn("Can't ragdoll on client, humanoid missing")
		return
	end

	PlayerContext.Humanoid:UnequipTools()
	PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	Inputs.networker:fire("ToggleSprint", false)
	task.delay(ragdollTime, function()
		if PlayerContext.Humanoid then
			PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function HumanNetwork:ApplyImpulse(target, force: Vector3, position: Vector3?)
	if not target then
		return
	end

	if position then
		target:ApplyImpulseAtPosition(force, position)
	else
		target:ApplyImpulse(force)
	end
end

function HumanNetwork:FinishedLoadingGame()
	self.networker:fire("FinishedLoadingGame")
end

function HumanNetwork:AdjustGrayscale(saturationTarget: number)
	ColorCorrection.Saturation = saturationTarget
end
return HumanNetwork
