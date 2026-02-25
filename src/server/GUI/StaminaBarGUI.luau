local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
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

	-- why numbervalue? syncs to client, utilizing its Changed connection for efficiency instead
	-- of sending a remote event every heartbeat
	local numberValue = Instance.new("NumberValue")
	numberValue.Name = "Stamina"
	numberValue.Value = HumanConstants.MAX_STAMINA
	numberValue.Parent = player.Character
	playerClass.StaminaValue = numberValue

	-- will auto disconnect when playerClass is removed (when player dies)
	playerClass.Janitor:Add(RunService.Heartbeat:Connect(function(dt)
		-- sprint
		if playerClass.Sprinting then
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
		end

		currentStamina = math.clamp(currentStamina, 0, HumanConstants.MAX_STAMINA)

		if currentStamina <= 0 then
			Inputs:ToggleSprint(player, false)
		end

		numberValue.Value = currentStamina
		playerClass.Stamina = currentStamina
	end))

	warn(`{player.DisplayName}'s stamina bar connected!`)
end

return StaminaBarGUI
