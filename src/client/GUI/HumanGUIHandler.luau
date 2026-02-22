local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local HumanGUIHandler = {}
HumanGUIHandler.janitor = Janitor.new()

function HumanGUIHandler.ConnectStaminaGUI(playerGUI: Instance, staminaValue: NumberValue)
	local staminaRef: Frame = Utility.GetInstance(playerGUI, true, "Bars", "Stamina")
	assert(staminaRef, "Stamina frame nil whilst connecting")
	local fill: Frame = Utility.GetInstance(staminaRef, true, "Fill")
	assert(fill, "Fill frame nil whilst connecting")

	HumanGUIHandler.janitor:Add(staminaValue.Changed:Connect(function(newStamina: number)
		fill.Size = UDim2.fromScale((1 / 100) * newStamina, fill.Size.Y.Scale)
	end))
end

function HumanGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return HumanGUIHandler
