local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local ClientUtility = require(StarterPlayer.StarterPlayerScripts.Client.Utility.ClientUtility)
local CoreGUIHandler = require(StarterPlayer.StarterPlayerScripts.Client.Utility.CoreGUIHandler)
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local ClientSoundHandler = require(script.Parent.Parent.Sound.ClientSoundHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local Inputs = {}
Inputs.networker = Networker.new("InputNetwork", Inputs)

local function FaceTowardsMovementDirection()
	if not PlayerContext.Humanoid then
		warn("Can't rotate character towards movement dir, missing player Humanoid")
		return
	end

	local flat = PlayerContext.Humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.001 then
		PlayerContext.HRPOrientation.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

function Inputs:ToggleBackpackVisibility(active: boolean)
	CoreGUIHandler.ToggleBackpackVisibility(active)
end

function Inputs:Initialize()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		-- sprint
		if input.KeyCode == Enum.KeyCode.LeftShift then
			if PlayerContext.Humanoid and PlayerContext.Humanoid.Health > 0 and PlayerContext.IsMoving then
				self.networker:fire("ToggleSprint", true)
			end
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
				FaceTowardsMovementDirection()
				rollAnim.Stopped:Once(function()
					PlayerContext.CanRoll = true
				end)
			end
		end

		-- kick
		if input.KeyCode == Enum.KeyCode.F then
			if not PlayerContext.CanKick then
				return
			end

			local kickActivated = self.networker:fetch("ApplyKickDrain")
			if not kickActivated then
				return
			end

			local kickAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("Kick")
			if not kickAnim then
				warn("Kick animation missing, restoring state")
				return
			end

			PlayerContext.CanKick = false
			ClientUtility.ToggleControls(false)

			kickAnim.Stopped:Once(function()
				PlayerContext.CanKick = true
				ClientUtility.ToggleControls(true)
			end)
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
			if PlayerContext.Humanoid and PlayerContext.Humanoid.Health > 0 then
				self.networker:fire("ToggleSprint", false)
			end
		end
	end)
end

return Inputs
