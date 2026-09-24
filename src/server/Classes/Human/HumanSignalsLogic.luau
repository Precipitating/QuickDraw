local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local HumanNetwork = require(script.Parent.HumanNetwork)
local StaminaBarGUI = require(ServerScriptService.Server.GUI.StaminaBarGUI)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local HumanSignals = require(script.Parent.HumanSignals)

return {
	HumanSignals.ConnectHumanGUIs:Connect(function(player: Player, humanoid: Humanoid)
		StaminaBarGUI:Connect(player, humanoid)
	end),
	HumanSignals.RagdollClient:Connect(function(player: Player, ragdollTime: number)
		HumanNetwork.networker:fire(player, "RagdollClient", ragdollTime)
	end),

	HumanSignals.AdjustGrayscale:Connect(function(player: Player, saturationTarget: number)
		HumanNetwork.networker:fire(player, "AdjustGrayscale", saturationTarget)
	end),
	HumanSignals.ApplyImpulseToClient:Connect(
		function(player: Player, target, force: Vector3, position: Vector3, type: string?)
			if not target then
				Utility.Warn("[ApplyImpulseToClient] missing target or is nil")
				return
			end

			if not player then
				HumanNetwork.networker:fireAll("ApplyImpulse", target, force, position, type)
			else
				HumanNetwork.networker:fire(player, "ApplyImpulse", target, force, position, type)
			end
		end
	),

	HumanSignals.SetShooterInCombat:Connect(function(player: Player)
		if not player then
			return
		end
		local human = PlayerManager:GetHumanClassFromPlayer(player)

		if not human then
			return
		end
		if human.SetInCombat then
			human:SetInCombat(true)
		end
	end),
}
