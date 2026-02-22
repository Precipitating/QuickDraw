-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

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
local ThirdPersonCameraConn = nil

local function ApplyMouseLock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end
-- if we die, update the refs
local function onCharacterAdded(character)
	PlayerContext.Character = character
	PlayerContext.Humanoid = character:WaitForChild("Humanoid")
	PlayerContext.PlayerGui = Player.PlayerGui
	PlayerContext.HRP = character:WaitForChild("HumanoidRootPart")

	-- cam reset
	local cam = workspace.CurrentCamera
	cam.CameraSubject = PlayerContext.Humanoid

	PlayerContext.Humanoid.AutoRotate = false
	PlayerContext.Humanoid.CameraOffset = Vector3.new(2, 1, -2)

	ThirdPersonCameraConn = RunService.RenderStepped:Connect(function()
		local camLook = PlayerContext.Camera.CFrame.LookVector
		-- ── Yaw: rotate HRP to face camera direction (horizontal) ──
		local flatLook = Vector3.new(camLook.X, 0, camLook.Z)
		if flatLook.Magnitude > 0.001 then
			PlayerContext.HRP.CFrame =
				CFrame.new(PlayerContext.HRP.Position, PlayerContext.HRP.Position + flatLook.Unit)
		end
	end)

	-- connect GUI events
	local staminaValue: NumberValue = Utility.GetInstance(character, true, "Stamina")
	HumanGUIHandler.ConnectStaminaGUI(PlayerContext.PlayerGui, staminaValue)

	PlayerContext.Humanoid.Died:Connect(function()
		ClientGunSignals.DisconnectGun:Fire()
		ThirdPersonCameraConn:Disconnect()
		HumanGUIHandler:Disconnect()
	end)

	ApplyMouseLock()
	print("Local character references updated!")
end

Player.CharacterAdded:Connect(onCharacterAdded)

return PlayerContext
