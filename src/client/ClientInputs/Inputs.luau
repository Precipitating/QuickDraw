local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local Inputs = {}
Inputs.networker = Networker.new("InputNetwork", Inputs)
local CanJump = true

function Inputs:Initialize()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.networker:fire("ToggleSprint", true)
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if not CanJump then
			return
		end
		CanJump = false
		local enoughStamina = self.networker:fetch("ApplyJumpDrain")

		if enoughStamina then
			PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.defer(function()
				PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			end)
		end

		task.wait(1)
		CanJump = true
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.networker:fire("ToggleSprint", false)
		end
	end)
end

return Inputs
