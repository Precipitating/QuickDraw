local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimationIds = require(ServerScriptService.Server.Classes.AnimationIds)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type HumanPlayer = ClassTypes.HumanPlayer
return {
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanClass: HumanPlayer = PlayerManager:AddHumanClass(player)
			local humanoid: Humanoid = character:WaitForChild("Humanoid")
			if not humanoid then
				error(`Missing humanoid for {player.DisplayName}`)
			end

			-- ragdoll
			humanoid.Died:Connect(function()
				humanClass:OnDeath()
			end)
			-- remove class
			humanoid.Destroying:Connect(function()
				humanClass:Destroy()
			end)
		end)
	end),
}
