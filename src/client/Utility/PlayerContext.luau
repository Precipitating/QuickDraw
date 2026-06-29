-- used to get up to date references to the player even if player dies
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ClientData = require(script.Parent.Parent.ClientData)
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

local HealthGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 0, 0)), -- 0% HP: Bright Red
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 100, 0)), -- 25% HP: Deep Orange
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 0)), -- 50% HP: Yellow-Orange
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(150, 220, 0)), -- 75% HP: Lime Green
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(0, 255, 0)), -- 100% HP: Pure Green
})

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
PlayerContext.HoldingWeapon = false
PlayerContext.IsCharging = false
PlayerContext.Legless = false
-- Helper function to evaluate the color at a specific percentage (0 to 1)
local function EvalColorSequence(sequence: ColorSequence, percentage: number): Color3
	local keypoints = sequence.Keypoints
	percentage = math.clamp(percentage, 0, 1)

	-- Find which two keypoints our percentage falls between
	for i = 1, #keypoints - 1 do
		local currentKey = keypoints[i]
		local nextKey = keypoints[i + 1]

		if percentage >= currentKey.Time and percentage <= nextKey.Time then
			-- Calculate how far we are between these two specific keypoints
			local alpha = (percentage - currentKey.Time) / (nextKey.Time - currentKey.Time)
			-- Blend smoothly between them
			return currentKey.Value:Lerp(nextKey.Value, alpha)
		end
	end

	return keypoints[#keypoints].Value
end

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

function PlayerContext:UpdateLimbsGUIHP(limbPartName: string, healthPercent: number?)
	if not self.LimbHPModel then
		return
	end
	local limb = self.LimbHPModel:WaitForChild(limbPartName, 5)
	if not limb then
		return
	end

	limb.Color = if not healthPercent then Color3.fromRGB(0, 0, 0) else EvalColorSequence(HealthGradient, healthPercent)
end

function PlayerContext:SetupLimbGUI()
	-- Get references
	if not self.Player or not self.Character then
		warn("[SetupLimbGUI] Missing character/Player ref")
		return
	end

	local gui = PlayerContext.PlayerGui and Utility.GetInstance(PlayerContext.PlayerGui, true, "LimbsHPGUI")
	if not gui then
		return
	end
	local success, rigClone = pcall(function()
		return Players:CreateHumanoidModelFromUserIdAsync(self.Player.UserId)
	end)

	if not success then
		return
	end

	rigClone:PivotTo(CFrame.fromEulerAnglesXYZ(0, math.rad(180), 0) + Vector3.new(0, 3, 0))

	-- Fixes accessory misplacement
	rigClone.Parent = workspace
	PlayerContext.LimbHPModel = rigClone

	rigClone.Parent = gui.Frame

	-- Set all bodypart to green, meaning 100% hp
	for _, part in rigClone:GetDescendants() do
		if part:IsA("Shirt") or part:IsA("ShirtGraphic") or part:IsA("Pants") then
			part:Destroy()
			continue
		end
		if not part:IsA("BasePart") then
			continue
		end
		part.Color = Color3.fromRGB(0, 255, 0)
	end
end

function PlayerContext:SyncLeglessState()
	self.janitor:Add(self.Character:GetAttributeChangedSignal("Legless"):Connect(function()
		PlayerContext.Legless = self.Character:GetAttribute("Legless")
	end))
end

local function RefreshPlayerContextRefs(player: Player, character: Model)
	assert(player, "Missing player when refreshing PlayerContext")
	assert(character, "Missing character when refreshing PlayerContext")

	local humanoid: Humanoid? = character:WaitForChild("Humanoid", 5) :: Humanoid
	local hrp = character:WaitForChild("HumanoidRootPart", 5)

	if not humanoid or not hrp then
		error("Cannot refresh PlayerContext, missing humanoid or HRP")
		return
	end

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
	PlayerContext.LimbHPModel = nil
	PlayerContext.HoldingWeapon = false
	PlayerContext.IsCharging = false
	PlayerContext.Legless = false
	PlayerContext.ActiveGUIs = {}

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
	CoreGUIHandler.ToggleBackpackVisibility(true, false)
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

	PlayerContext:SetupLimbGUI()

	-- Sync legless state attribute that changes from server
	PlayerContext:SyncLeglessState()
end

local function ConnectGUIConnections(character: Model)
	HumanGUIHandler.ConnectStaminaGUI(PlayerContext.PlayerGui, character)
end

local function DisconnectActiveGUIs()
	for guiRef, disconnectFunc in PlayerContext.ActiveGUIs do
		disconnectFunc()
	end
end

local function OnDeath()
	PlayerContext.Humanoid.Died:Once(function()
		PlayerContext.janitor:Cleanup()
		HumanGUIHandler:Disconnect()
		PlayerContext.ColorCorrector.Saturation = -1
		DisconnectActiveGUIs()
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
