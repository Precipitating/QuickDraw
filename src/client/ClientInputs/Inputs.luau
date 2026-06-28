local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CrosshairHandler = require(script.Parent.Parent.GUI.CrosshairHandler)
local QuestGUIHandler = require(script.Parent.Parent.GUI.QuestGUIHandler)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
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

function Inputs:ToggleBackpackVisibility(active: boolean, locked: boolean?)
	CoreGUIHandler.ToggleBackpackVisibility(active, locked)
end

function Inputs:ConnectSprint(input: InputObject)
	if not input then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if PlayerContext.IsCharging then
			return
		end
		if PlayerContext.Humanoid and PlayerContext.Humanoid.Health > 0 and PlayerContext.IsMoving then
			self.networker:fire("ToggleSprint", true)
		end
	end
end

function Inputs:ConnectRoll(input: InputObject)
	if not input then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		if not PlayerContext.CanRoll then
			return
		end

		if CollectionService:HasTag(PlayerContext.Player, "Jailed") then
			return
		end

		if PlayerContext.IsCharging then
			return
		end

		if PlayerContext.IsCharging then
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
end

function Inputs:ConnectKick(input: InputObject)
	if not input then
		return
	end

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
end

function Inputs:ConnectOnJump()
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

		task.delay(1, function()
			PlayerContext.CanJump = true
		end)
	end)
end

function Inputs:ConnectInputEnd()
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			if PlayerContext.IsCharging then
				return
			end
			if PlayerContext.Humanoid and PlayerContext.Humanoid.Health > 0 then
				self.networker:fire("ToggleSprint", false)
			end
		end
	end)
end

function Inputs:ConnectInputBegin()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		self:ConnectSprint(input)
		self:ConnectRoll(input)
		self:ConnectKick(input)
		self:ConnectBarge(input)
		self:ConnectQuests(input)
	end)
end

function Inputs:StopBarge(hitType: string)
	if not PlayerContext.janitor:Get("BargeConn") then
		return
	end

	local function ResetBarge()
		local humanoid = PlayerContext.Humanoid
		PlayerContext.janitor:Remove("BargeConn")

		AnimationsHandler.StopCustomAnimation("BargeRun")
		PlayerContext.IsCharging = false
		Inputs.networker:fire("ToggleSprint", false)
		self.networker:fire("DestroyBargeCollision")
		if humanoid then
			humanoid:Move(Vector3.new(0, 0, 0), false)
		end
	end

	ResetBarge()

	-- Hit a wall, play a custom stagger animation
	if hitType and hitType == "Environment" then
		SoundManager.PlayKeyed("SFX", "ImpactHit")
		local bargeHitEnvAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("BargeHitEnvironment")

		bargeHitEnvAnim.Ended:Once(function()
			ResetBarge()
			CoreGUIHandler.ToggleBackpackVisibility(true, false)
			ClientUtility.ToggleControls(true)
		end)
		return
	end

	CoreGUIHandler.ToggleBackpackVisibility(true, false)
	ClientUtility.ToggleControls(true)
end

function Inputs:ConnectBarge(input: InputObject)
	if not input then
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		if
			not PlayerContext.Humanoid
			or PlayerContext.Humanoid.Health <= 0
			or PlayerContext.IsMoving
			or PlayerContext.Legless
			or PlayerContext.IsCharging
		then
			return
		end
		PlayerContext.IsCharging = true
		local canBarge = self.networker:fetch("CanBarge")
		if not canBarge then
			PlayerContext.IsCharging = false
			return
		end

		ClientUtility.ToggleControls(false)
		CoreGUIHandler.ToggleBackpackVisibility(false, true)
		local bargeWindupAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("BargeWindup")

		bargeWindupAnim.Ended:Once(function()
			if not PlayerContext or not PlayerContext.Humanoid or not PlayerContext.HRP then
				return
			end
			if not PlayerContext.IsCharging then
				return
			end
			if PlayerContext.Legless then
				return
			end

			-- Play animation and run until stamina runs out
			AnimationsHandler.PlayCustomAnimation("BargeRun")
			Inputs.networker:fire("ToggleSprint", true)
			self.networker:fire("AddBargeCollision")

			PlayerContext.janitor:Add(
				RunService.RenderStepped:Connect(function()
					PlayerContext.Player:Move(PlayerContext.HRP.CFrame.LookVector)

					if PlayerContext.Legless then
						self:StopBarge("None")
					end
				end),
				"Disconnect",
				"BargeConn"
			)
		end)
	end
end

-- Is called when player's stamina has touched 0
function Inputs:StaminaDepleted()
	self:StopBarge("None")
end

function Inputs:ConnectQuests(input: InputObject)
	if not input then
		return
	end

	if input.KeyCode ~= Enum.KeyCode.M then
		return
	end

	local gui = Utility.GetInstance(PlayerContext.PlayerGui, true, "QuestsGUI")
	if not gui then
		warn("Cannot get QuestGUI reference!")
		return
	end
	PlayerContext.ApplyMouseLock(false)

	QuestGUIHandler:ConnectQuestGUI(gui)
end

function Inputs:Initialize()
	self:ConnectInputBegin()
	self:ConnectInputEnd()
	self:ConnectOnJump()
end

return Inputs
