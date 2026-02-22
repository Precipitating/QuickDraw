local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Inputs = {}
Inputs.networker = Networker.new("InputNetwork", Inputs)

function Inputs:Initialize()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.networker:fire("ToggleSprint", true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.networker:fire("ToggleSprint", false)
		end
	end)
end

return Inputs
