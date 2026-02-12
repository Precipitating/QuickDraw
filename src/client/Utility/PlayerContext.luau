-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")

local PlayerContext = {}
local Player: Player = Players.LocalPlayer
Player.CharacterAdded:Wait()

PlayerContext.Player = Player
PlayerContext.Character = Player.Character
PlayerContext.PlayerGui = Player.PlayerGui
PlayerContext.HRP = PlayerContext.Character:WaitForChild("HumanoidRootPart")
PlayerContext.Humanoid = PlayerContext.Character:WaitForChild("Humanoid")
PlayerContext.Camera = workspace.CurrentCamera

-- if we die, update the refs
local function onCharacterAdded(character)
	PlayerContext.Character = character
	PlayerContext.Humanoid = character:WaitForChild("Humanoid")
	PlayerContext.PlayerGui = Player.PlayerGui
	PlayerContext.HRP = character:WaitForChild("HumanoidRootPart")
	print("Local character references updated!")
end

Player.CharacterAdded:Connect(onCharacterAdded)

return PlayerContext
