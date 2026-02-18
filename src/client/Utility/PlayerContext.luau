-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local ClientGunSignals = require(StarterPlayer.StarterPlayerScripts.Client.Gun.ClientGunSignals)

local PlayerContext = {}
local Player: Player = Players.LocalPlayer

PlayerContext.Player = Player
PlayerContext.Character = nil
PlayerContext.PlayerGui = Player.PlayerGui
PlayerContext.HRP = nil
PlayerContext.Humanoid = nil
PlayerContext.Camera = workspace.CurrentCamera

-- if we die, update the refs
local function onCharacterAdded(character)
	PlayerContext.Character = character
	PlayerContext.Humanoid = character:WaitForChild("Humanoid")
	PlayerContext.PlayerGui = Player.PlayerGui
	PlayerContext.HRP = character:WaitForChild("HumanoidRootPart")

	local cam = workspace.CurrentCamera
	cam.CameraSubject = PlayerContext.Humanoid

	PlayerContext.Humanoid.Died:Connect(function()
		ClientGunSignals.DisconnectGun:Fire()
	end)

	print("Local character references updated!")
end

Player.CharacterAdded:Connect(onCharacterAdded)

return PlayerContext
