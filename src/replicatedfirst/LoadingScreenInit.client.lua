local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local ROTATION_SPEED = 10 -- in degrees

local player = Players.LocalPlayer
local playerGUI = player:WaitForChild("PlayerGui")

local loadingScreen = ReplicatedFirst:WaitForChild("LoadingScreen"):Clone()
loadingScreen.Parent = playerGUI

local bg = loadingScreen:WaitForChild("BG")
local loadingLabel = bg:WaitForChild("LoadingLabel")
local revolver = bg:WaitForChild("Gun")
local loadCountLabel = bg:WaitForChild("LoadCount")

local rotationConn = game:GetService("RunService").RenderStepped:Connect(function()
	revolver.Rotation = (revolver.Rotation + ROTATION_SPEED) % 360
end)

local assets = game:GetDescendants()

for idx, asset in assets do
	ContentProvider:PreloadAsync({ asset })
	loadCountLabel.Text = `{idx}/{#assets}`
end

rotationConn:Disconnect()
loadingScreen:Destroy()

CollectionService:AddTag(player, "ClientLoaded")
