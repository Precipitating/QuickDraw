local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Constants = require(ServerScriptService.Server.Classes.Constants)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

local Networker = require(ReplicatedStorage.Packages.Networker).server
local Inputs = {}

function Inputs:ApplyJumpDrain(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)

	if humanClass.Legless then
		return
	end
	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return
	end

	if humanClass.Stamina < Constants.JUMP_DRAIN then
		print("CANT")
		return false
	end
	humanClass.JumpSignalled = true
	return true
end

function Inputs:ToggleSprint(player: Player, active: boolean)
	local humanClass, humanoid = PlayerManager:GetHumanClassFromPlayer(player)
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

Inputs.networker = Networker.new("InputNetwork", Inputs, { Inputs.ToggleSprint, Inputs.ApplyJumpDrain })
return Inputs
