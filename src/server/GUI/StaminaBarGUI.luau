local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Inputs = require(ServerScriptService.Server.ServerInputs.Inputs)

local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local StaminaBarGUI = {}

function StaminaBarGUI:Connect(player: Player, humanoid: Humanoid?)
	local staminaFrame = Utility.GetInstance(player.PlayerGui, true, "Bars", "Stamina")
	assert(staminaFrame, "[StaminaBar->Connect] StaminaFrame reference not valid!")
	assert(humanoid, "[StaminaBar->Connect] Humanoid invalid")

	local playerClass = PlayerManager:GetHumanClass(humanoid)
	Inputs:BindHumanStamina(player, playerClass)

	Utility.Warn(`{player.DisplayName}'s stamina bar connected!`)
end

return StaminaBarGUI
