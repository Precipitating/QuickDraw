local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Utility.PlayerContext)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)

require(script.Animations.AnimationSignalsLogic)
require(script.ClientData).Initialize()
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

-- local npcList = {}
-- task.spawn(function()
-- 	local renderDist = 150
-- 	local cam = workspace.CurrentCamera
-- 	while task.wait(1) do
-- 		local npcs = CollectionService:GetTagged("NPC")

-- 		for _, npc in npcs do
-- 			if (cam.CFrame.Position - npc:GetPivot().Position).Magnitude <= renderDist then

-- 			end
-- 		end
-- 	end

-- end)
