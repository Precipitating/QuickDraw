local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Utility.PlayerContext)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
require(script.Sound.ClientSoundHandler)
require(script.Gun.ClientGunHandler)
require(script.Throwable.ClientThrowableHandler)
require(script.ClientInputs.Inputs):Initialize()
SoundManager.Init()
SoundManager.PlayKeyed("Music", "MainTheme", { FadeIn = 0.5 })

local Player = Players.LocalPlayer

Player.CharacterAdded:Connect(function(character: Model)
	PlayerContext.OnCharacterAdded(Player, character)
end)

if Player.Character then
	PlayerContext.OnCharacterAdded(Player, Player.Character)
end
