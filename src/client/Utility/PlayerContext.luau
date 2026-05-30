-- used to get up to date references to the player even if player dies
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ClientData = require(StarterPlayer.StarterPlayerScripts.Client.ClientData)
local ClientUtility = require(script.Parent.ClientUtility)
local CoreGUIHandler = require(script.Parent.CoreGUIHandler)
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AnimationController = require(ReplicatedStorage.Shared.AnimationData.AnimationController)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local WindConstants = require(ReplicatedStorage.Shared.Wind.WindConstants)
local WindLines = require(ReplicatedStorage.Shared.Wind.WindLines)
local WindShake = require(ReplicatedStorage.Shared.Wind.WindShake)
local HumanGUIHandler = require(script.Parent.Parent.GUI.HumanGUIHandler)
local CurrentCamera = workspace.CurrentCamera
local DefaultAnimations = ReplicatedStorage.Shared.AnimationData.DefaultAnimations
local Player = Players.LocalPlayer

local Crosshair = ReplicatedStorage.Shared.Templates.Crosshair
local DefaultAnimateParams = {
	ApplyRigScale = true,
	SprintDetectSpeed = 30,
	SprintSpeedDividend = 16,
	RunDetectSpeed = 24,
	RunSpeedDividend = 16,
	WalkSpeedDividend = 6,
	JumpDuration = 0.3,
	ClimbSpeedDividend = 12,
	SwimSpeedDividend = 16,
	LandedDuration = 0.6,
}

local PlayerContext = {}

PlayerContext.Player = nil
PlayerContext.Character = nil
PlayerContext.PlayerGui = nil
PlayerContext.HRP = nil
PlayerContext.Humanoid = nil
PlayerContext.Camera = nil
PlayerContext.RightArmYaw = nil
PlayerContext.janitor = Janitor.new()
PlayerContext.HRPOrientation = nil

function PlayerContext.ApplyMouseLock(on: boolean)
	if on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function PlayerContext:PlayerFollowCamera()
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.RigidityEnabled = true
	align.Attachment0 = self.HRP.RootAttachment
	align.Parent = self.HRP
	self.HRPOrientation = align

	self.janitor:Add(
		RunService.RenderStepped:Connect(function()
			if not self.CanRoll then
				return
			end
			local flat = CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.001 then
				align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
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
	align.RigidityEnabled = true
	align.Parent = rightArm
	align.Enabled = false
	rightArmBallSocket.TwistLimitsEnabled = true
	rightArmBallSocket.TwistUpperAngle = 175
	rightArmBallSocket.TwistLowerAngle = 0
	self.RightArmYaw = align
end
function PlayerContext.StayOnMovingPlatform(movingPart: BasePart | Model)
	if not movingPart then
		return
	end
	local character = Player.Character
	if not character then
		return
	end

	PlayerContext.LastMovingPlatformCFrame = movingPart:GetPivot()
	PlayerContext.janitor:Add(
		RunService.Heartbeat:Connect(function(dt: number)
			local partCFrame = movingPart:GetPivot()
			local delta = partCFrame * PlayerContext.LastMovingPlatformCFrame:Inverse()
			character:PivotTo(delta * character:GetPivot())
			PlayerContext.LastMovingPlatformCFrame = partCFrame
		end),
		"Disconnect",
		"MovingPlatformConn"
	)
end

local function RefreshPlayerContextRefs(player: Player, character: Model)
	assert(player, "Missing player when refreshing PlayerContext")
	assert(character, "Missing character when refreshing PlayerContext")

	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	PlayerContext.Player = player
	PlayerContext.Character = character or player.CharacterAdded:Wait()
	PlayerContext.Humanoid = humanoid
	PlayerContext.HRP = hrp
	PlayerContext.CanJump = true
	PlayerContext.CanRoll = true
	PlayerContext.CanKick = true
	PlayerContext.PlayerGui = player:WaitForChild("PlayerGui", 10)
	PlayerContext.AnimationController = AnimationController.new(character, DefaultAnimations, DefaultAnimateParams)
	PlayerContext.IsMoving = false
	PlayerContext.Reloading = false
	PlayerContext.MovingPlatformConn = nil
	PlayerContext.LastMovingPlatformCFrame = nil

	PlayerContext.ColorCorrector = Lighting:WaitForChild("ColorCorrection", 10) :: ColorCorrectionEffect
	PlayerContext.BodyParts = {}
	for _, obj in character:GetChildren() do
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

	ClientUtility.ToggleControls(true)

	CurrentCamera.CameraSubject = humanoid
	-- connect events
	PlayerContext.janitor:Add(
		humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.GettingUp then
				CoreGUIHandler.ToggleBackpackVisibility(true)
				hrp.CanCollide = true
				PlayerContext.HRPOrientation.Enabled = true
				ClientUtility.ToggleControls(true)
			elseif new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.Dead then
				CoreGUIHandler.ToggleBackpackVisibility(false)
				humanoid:UnequipTools()
				hrp.CanCollide = false
				PlayerContext.HRPOrientation.Enabled = false
				ClientUtility.ToggleControls(false)
			end
		end)
	)

	PlayerContext.janitor:Add(humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 then
			PlayerContext.IsMoving = true
		else
			PlayerContext.IsMoving = false
		end
	end))
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
	PlayerContext.AnimationController:Load()
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

local function SetupWind()
	-- Wind shake
	WindShake:Init({
		MatchWorkspaceWind = false,
	})

	WindShake:SetDefaultSettings({
		WindSpeed = WindConstants.WindSpeed,
		WindDirection = WindConstants.WindDirection,
		WindPower = WindConstants.WindPower,
	})
	WindLines:Init({
		Direction = WindConstants.WindDirection,
		Speed = WindConstants.WindSpeed,
		Lifetime = WindConstants.WindLifetime,
		SpawnRate = WindConstants.WindSpawnRate,
	})
end

function PlayerContext:Initialize()
	ClientData.WaitForData()
	-- Needs reinitializing on respawn
	Player.CharacterAdded:Connect(function(character: Model)
		self.OnCharacterAdded(Player, character)
	end)

	if Player.Character then
		self.OnCharacterAdded(Player, Player.Character)
	end
	-- Crosshair
	local crosshair = Crosshair:Clone()
	crosshair.Parent = workspace

	ContextActionService:BindActionAtPriority("RightMouseDisable", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Low.Value, Enum.UserInputType.MouseButton2)

	SetupWind()
end

return PlayerContext
