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
	local currentStamina = playerClass.Stamina

	-- will auto disconnect when playerClass is removed (when player dies)
	playerClass.Janitor:Add(RunService.Heartbeat:Connect(function(dt)
		-- sprint
		if playerClass.Moving and playerClass.Sprinting then
			currentStamina -= HumanConstants.STAMINA_DRAIN_RATE * dt
		else
			currentStamina += HumanConstants.STAMINA_REGEN_RATE * dt
		end

		-- jump
		if playerClass.JumpSignalled and currentStamina >= HumanConstants.JUMP_DRAIN then
			currentStamina -= HumanConstants.JUMP_DRAIN
			playerClass.JumpSignalled = false
		end

		-- roll
		if playerClass.RollSignalled and currentStamina >= HumanConstants.ROLL_DRAIN then
			currentStamina -= HumanConstants.ROLL_DRAIN
			playerClass.RollSignalled = false
		end

		-- kick

		if playerClass.KickSignalled and currentStamina >= HumanConstants.KICK_DRAIN then
			currentStamina -= HumanConstants.KICK_DRAIN
			playerClass.KickSignalled = false
		end

		currentStamina = math.clamp(currentStamina, 0, HumanConstants.MAX_STAMINA)

		if currentStamina <= 0 then
			if humanoid and humanoid.Health > 0 then
				Inputs:ToggleSprint(player, false)
				Inputs.networker:fire(player, "StaminaDepleted")
			end
		end

		playerClass.Character:SetAttribute("Stamina", currentStamina)
		playerClass.Stamina = currentStamina
	end))

	warn(`{player.DisplayName}'s stamina bar connected!`)
end

return StaminaBarGUI
