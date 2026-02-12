local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Character = Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local HRP = Character:WaitForChild("HumanoidRootPart")

return {
	Humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.GettingUp then
			HRP.CanCollide = true
		else
			HRP.CanCollide = false
		end
	end),
}
