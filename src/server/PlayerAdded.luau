local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Human = require(ReplicatedStorage.Shared.Classes.Human)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

type Human = Human.Human
return {
	game.Players.PlayerAdded:Connect(function(player)
		PlayerManager:AddHumanClass(player)
	end),
}
