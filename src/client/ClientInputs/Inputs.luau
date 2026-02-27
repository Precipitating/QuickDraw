local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local ClientSoundHandler = require(script.Parent.Parent.Sound.ClientSoundHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local Inputs = {}
Inputs.networker = Networker.new("InputNetwork", Inputs)

function Inputs:Initialize()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		-- sprint
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.networker:fire("ToggleSprint", true)
		end

		-- roll
		if input.KeyCode == Enum.KeyCode.E then
			if not PlayerContext.CanRoll then
				return
			end

			local rollActivated = self.networker:fetch("ApplyRollDrain", PlayerContext.HRP.CFrame.LookVector)

			if rollActivated then
				PlayerContext.CanRoll = false
				local rollAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("Roll")
				PlayerContext.Humanoid:UnequipTools()
				ClientSoundHandler:PlayOneShot("Roll")
				rollAnim.Stopped:Once(function()
					PlayerContext.CanRoll = true
				end)
			end
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if not PlayerContext.CanJump then
			return
		end
		PlayerContext.CanJump = false
		local enoughStamina = self.networker:fetch("ApplyJumpDrain")

		if enoughStamina then
			PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.defer(function()
				PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			end)
		end

		task.wait(1)
		PlayerContext.CanJump = true
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
