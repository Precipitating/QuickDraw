local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ServerScriptService.Server.Classes.Constants)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).server
local Inputs = {}

function Inputs:ToggleSprint(player: Player, active: boolean)
	local character = player.Character
	local humanoid: Humanoid? = Utility.GetInstance(character, true, "Humanoid")
	assert(humanoid, "[Inputs:ToggleSprint] Humanoid is nil")

	local humanClass = PlayerManager:GetHumanClass(humanoid)
	assert(humanClass, "[Inputs:ToggleSprint] Reference to humanClass is nil")
	local stamina = humanClass.Stamina

	if humanClass.Legless then
		return
	end

	if active and stamina > 0 then
		humanoid.WalkSpeed = Constants.SPRINT_SPEED
		stamina = math.clamp(stamina, 0, Constants.MAX_STAMINA)
		humanClass.Sprinting = true
	else
		humanoid.WalkSpeed = Constants.WALKSPEED
		humanClass.Sprinting = false
	end
end

Inputs.networker = Networker.new("InputNetwork", Inputs, { Inputs.ToggleSprint })
return Inputs
