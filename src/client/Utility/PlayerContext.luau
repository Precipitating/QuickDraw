-- used to get up to date references to the player even if player dies
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGUIHandler = require(script.Parent.CoreGUIHandler)
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local HumanGUIHandler = require(script.Parent.Parent.GUI.HumanGUIHandler)
local CurrentCamera = workspace.CurrentCamera
local PlayerContext = {}

PlayerContext.Player = nil
PlayerContext.Character = nil
PlayerContext.PlayerGui = nil
PlayerContext.HRP = nil
PlayerContext.Humanoid = nil
PlayerContext.Camera = nil
PlayerContext.RightArmYaw = nil
PlayerContext.janitor = Janitor.new()

function PlayerContext.ApplyMouseLock(on: boolean)
	if on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function PlayerContext:PlayerFollowCamera()
	-- body moves with cam
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Responsiveness = 1000
	align.RigidityEnabled = true

	local attachment = Instance.new("Attachment")
	attachment.Parent = self.HRP

	align.Attachment0 = attachment
	align.Parent = self.HRP

	self.janitor:Add(
		RunService.RenderStepped:Connect(function()
			local camLook = CurrentCamera.CFrame.LookVector
			local flatLook = Vector3.new(camLook.X, 0, camLook.Z)

			if flatLook.Magnitude > 0.001 then
				align.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
			end
		end),
		"Disconnect",
		"FollowCamera"
	)
end

-- for yaw aiming when equipping a tool
function PlayerContext:AddRightArmOrientation()
	local align = Instance.new("AlignOrientation")
	local rightArm = self.BodyParts["RightUpperArm"]
	local rightArmBallSocket: BallSocketConstraint = rightArm:WaitForChild("RightShoulderBallSocket")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = rightArm:WaitForChild("RightShoulderAttachment")
	align.RigidityEnabled = false
	align.Name = "RightArmYawOrientation"
	align.MaxTorque = 90000
	align.MaxAngularVelocity = 15000

	align.Responsiveness = 150
	align.Parent = rightArm
	align.Enabled = false
	rightArmBallSocket.TwistLimitsEnabled = true
	rightArmBallSocket.TwistUpperAngle = 175
	rightArmBallSocket.TwistLowerAngle = 0
	self.RightArmYaw = align
end
local function RefreshPlayerContextRefs(player: Player, character: Model)
	assert(player, "Missing player when refreshing PlayerContext")
	assert(character, "Missing character when refreshing PlayerContext")

	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	PlayerContext.Player = player
	PlayerContext.Character = character
	PlayerContext.Humanoid = humanoid
	PlayerContext.HRP = hrp
	PlayerContext.CanJump = true
	PlayerContext.CanRoll = true
	PlayerContext.PlayerGui = player:WaitForChild("PlayerGui", 10)
	PlayerContext.ColorCorrector = Lighting:WaitForChild("ColorCorrection", 10) :: ColorCorrectionEffect
	PlayerContext.BodyParts = {}
	for _, obj in pairs(character:GetChildren()) do
		if not obj:IsA("MeshPart") then
			continue
		end
		PlayerContext.BodyParts[obj.Name] = obj
	end

	-- Configure humanoid safely
	humanoid.AutoRotate = false
	humanoid.CameraOffset = Vector3.new(2, 1, -2)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- Reset colour corrector
	PlayerContext.ColorCorrector.Saturation = 0
	CoreGUIHandler.ToggleBackpackVisibility(true)

	-- connect events
	PlayerContext.janitor:Add(
		humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.GettingUp then
				CoreGUIHandler.ToggleBackpackVisibility(true)
				hrp.CanCollide = true
			elseif new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.Dead then
				CoreGUIHandler.ToggleBackpackVisibility(false)
				humanoid:UnequipTools()
				hrp.CanCollide = false
			end
		end)
	)
end

local function ConnectGUIConnections(character: Model)
	local staminaValue: NumberValue = Utility.GetInstance(character, true, "Stamina")
	HumanGUIHandler.ConnectStaminaGUI(PlayerContext.PlayerGui, staminaValue)
end

local function OnDeath()
	PlayerContext.Humanoid.Died:Once(function()
		PlayerContext.janitor:Cleanup()
		HumanGUIHandler:Disconnect()
		PlayerContext.ColorCorrector.Saturation = -1
	end)
end

local function ReloadCustomAnimations()
	assert(PlayerContext.Humanoid, "PlayerContext missing humanoid ref")
	AnimationsHandler.LoadCustomAnimations(PlayerContext.Humanoid)
end

-- if we die, update the refs
function PlayerContext.OnCharacterAdded(player: Player, character: Model)
	assert(player, "Missing player when refreshing PlayerContext")
	assert(character, "Missing character when refreshing PlayerContext")

	RefreshPlayerContextRefs(player, character)
	PlayerContext:PlayerFollowCamera()
	PlayerContext:AddRightArmOrientation()
	ConnectGUIConnections(character)
	OnDeath()
	ReloadCustomAnimations()
	PlayerContext.ApplyMouseLock(true)
	UserInputService.MouseIconEnabled = false

	warn("Local character references updated!")
end

return PlayerContext
