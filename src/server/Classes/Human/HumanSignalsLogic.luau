local ServerScriptService = game:GetService("ServerScriptService")
local HumanNetwork = require(script.Parent.HumanNetwork)
local StaminaBarGUI = require(ServerScriptService.Server.GUI.StaminaBarGUI)
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
	HumanSignals.ApplyImpulseToClient:Connect(function(player: Player, target, force: Vector3, position: Vector3)
		if not target then
			warn("[ApplyImpulseToClient] missing target or is nil")
			return
		end

		if not player then
			HumanNetwork.networker:fireAll("ApplyImpulse", target, force, position)
		else
			HumanNetwork.networker:fire(player, "ApplyImpulse", target, force, position)
		end
	end),
}
