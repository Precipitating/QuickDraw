local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ClientGunHandler = require(StarterPlayer.StarterPlayerScripts.Client.Gun.ClientGunHandler)
local CoreGUIHandler = require(StarterPlayer.StarterPlayerScripts.Client.Utility.CoreGUIHandler)
local Player = Players.LocalPlayer
local Character = Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

local PlayerEvents = {}

function PlayerEvents.Initialize()
	CoreGUIHandler.ToggleBackpackVisibility(false)

	Humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.GettingUp then
			HRP.CanCollide = true
		else
			HRP.CanCollide = false
		end
	end)
end

return PlayerEvents
