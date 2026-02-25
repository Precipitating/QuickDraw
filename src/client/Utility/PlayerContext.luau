-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local AnimationsHandler = require(StarterPlayer.StarterPlayerScripts.Client.Animations.AnimationsHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local HumanGUIHandler = require(StarterPlayer.StarterPlayerScripts.Client.GUI.HumanGUIHandler)
local ClientGunSignals = require(StarterPlayer.StarterPlayerScripts.Client.Gun.ClientGunSignals)

local PlayerContext = {}
local Player: Player = Players.LocalPlayer

PlayerContext.Player = Player
PlayerContext.Character = nil
PlayerContext.PlayerGui = Player.PlayerGui
PlayerContext.HRP = nil
PlayerContext.Humanoid = nil
PlayerContext.Camera = workspace.CurrentCamera
PlayerContext.janitor = Janitor.new()

local function ApplyMouseLock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

local function PlayerFollowCamera()
	-- body moves with
	PlayerContext.janitor:Add(RunService.RenderStepped:Connect(function()
		local camLook = PlayerContext.Camera.CFrame.LookVector
		-- ── Yaw: rotate HRP to face camera direction (horizontal) ──
		local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
		if flatLook.Magnitude > 0.001 then
			PlayerContext.HRP.CFrame =
				CFrame.new(PlayerContext.HRP.Position, PlayerContext.HRP.Position + flatLook.Unit)
		end
	end))
end

local function RefreshPlayerContextRefs(character: Model)
	if not character then
		return
	end
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	PlayerContext.Character = character
	PlayerContext.Humanoid = humanoid
	PlayerContext.HRP = hrp
	PlayerContext.PlayerGui = Player:WaitForChild("PlayerGui")

	-- Configure humanoid safely
	humanoid.AutoRotate = false
	humanoid.CameraOffset = Vector3.new(2, 1, -2)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
end

local function ConnectGUIConnections(character: Model)
	local staminaValue: NumberValue = Utility.GetInstance(character, true, "Stamina")
	HumanGUIHandler.ConnectStaminaGUI(PlayerContext.PlayerGui, staminaValue)
end

local function OnDeath()
	PlayerContext.Humanoid.Died:Connect(function()
		ClientGunSignals.DisconnectGun:Fire()
		PlayerContext.janitor:Cleanup()
		HumanGUIHandler:Disconnect()
	end)
end

local function ReloadCustomAnimations()
	assert(PlayerContext.Humanoid, "PlayerContext missing humanoid ref")
	AnimationsHandler.LoadCustomAnimations(PlayerContext.Humanoid)
end

-- if we die, update the refs
local function onCharacterAdded(character: Model)
	RefreshPlayerContextRefs(character)
	PlayerFollowCamera()
	ConnectGUIConnections(character)
	OnDeath()
	ReloadCustomAnimations()
	ApplyMouseLock()

	print("Local character references updated!")
end

Player.CharacterAdded:Connect(onCharacterAdded)

return PlayerContext
