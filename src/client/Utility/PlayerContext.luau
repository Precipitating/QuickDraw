-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")

local PlayerContext = {}
local Player: Player = Players.LocalPlayer

PlayerContext.Player = Player
PlayerContext.Character = nil
PlayerContext.Humanoid = nil
PlayerContext.Camera = workspace.CurrentCamera

local function onCharacterAdded(character)
	PlayerContext.Character = character
	PlayerContext.Humanoid = character:WaitForChild("Humanoid")
	PlayerContext.PlayerGui = Player.PlayerGui
	PlayerContext.Camera.CameraType = Enum.CameraType.Custom
	PlayerContext.Camera.CameraSubject = character.Humanoid
	local PlayerModule = PlayerContext.Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	local controls = require(PlayerModule):GetControls()
	controls:Enable()
end

Player.CharacterAdded:Connect(onCharacterAdded)

if Player.Character then
	onCharacterAdded(Player.Character)
end

return PlayerContext
