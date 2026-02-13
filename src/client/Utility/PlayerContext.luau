-- used to get up to date references to the player even if player dies
local Players = game:GetService("Players")

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
	print("Local character references updated!")
end

Player.CharacterAdded:Connect(onCharacterAdded)

return PlayerContext
