local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type Human = ClassTypes.Human
return {
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanClass: Human = PlayerManager:AddHumanClass(player)
			local humanoid: Humanoid = character.Humanoid
			if not humanoid then
				error(`Missing humanoid for {player.DisplayName}`)
			end

			humanoid.Died:Connect(function()
				humanClass:OnDeath()
			end)
		end)
	end),
	Players.PlayerRemoving:Connect(function(player: Player)
		local humanClass: Human = PlayerManager:GetHumanClass(player)
		if not humanClass then
			warn(`{player} left but they don't have a human class to destroy!`)
			return
		end

		humanClass:Destroy()
	end),
}
