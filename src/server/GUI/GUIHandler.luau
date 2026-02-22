local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StaminaBarGUI = require(script.Parent.StaminaBarGUI)

local Networker = require(ReplicatedStorage.Packages.Networker).server
local GUIHandler = {}

function GUIHandler:ConnectStamina(player: Player, humanoid: Humanoid)
	assert(player, "[GUIHandler:ConnectStamina] Missing player")
	assert(humanoid, "[GUIHandler:ConnectStamina] Missing humanoid")

	StaminaBarGUI:Connect(player, humanoid)
end

GUIHandler.networker = Networker.new("GUINetwork", GUIHandler)
return GUIHandler
