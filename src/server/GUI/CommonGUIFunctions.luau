local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local CommonGUIFunctions = {}

function CommonGUIFunctions:OnGUIOpen(player: Player, npcModel: Model)
	if not player or not npcModel then
		return
	end
	if not player.Character then
		return
	end

	if (player.Character:GetPivot().Position - npcModel:GetPivot().Position).Magnitude > 10 then
		warn(`{player.Name} is too far from NPC`)
		return
	end

	local human = PlayerManager:GetHumanClassFromPlayer(player)

	if human then
		human:SetInvincibleFor(HumanConstants.GUI_INTERACTION_INVINCIBILITY_TIME, false)
	end
end
function CommonGUIFunctions:OnGUIClose(player: Player)
	local human = PlayerManager:GetHumanClassFromPlayer(player)

	if human then
		human:SetInvincible(false)
		if human.ActiveInvincibleDelayHandle then
			task.cancel(human.ActiveInvincibleDelayHandle)
		end
	end
end

return CommonGUIFunctions
