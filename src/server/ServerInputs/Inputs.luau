local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)

local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

local Networker = require(ReplicatedStorage.Packages.Networker).server
local Inputs = {}

function Inputs:ApplyJumpDrain(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	local humanoid = humanClass.Humanoid

	if not humanoid then
		warn("Missing humanoid reference to apply jump drain, probably dead")
		return false
	end
	if humanClass.Legless then
		return false
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end

	if humanClass.Stamina < HumanConstants.JUMP_DRAIN then
		return false
	end
	humanClass.JumpSignalled = true
	return true
end

function Inputs:ApplyRollDrain(player: Player, lookDir: Vector3)
	assert(lookDir, "Missing lookDir from client to roll!")
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)

	if humanClass.Legless then
		return false
	end
	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end

	if humanClass.Stamina < HumanConstants.JUMP_DRAIN then
		return false
	end
	humanClass.RollSignalled = true
	humanClass:ApplyRollForce(lookDir)
	return true
end

function Inputs:ToggleSprint(player: Player, active: boolean)
	local humanClass, humanoid = PlayerManager:GetHumanClassFromPlayer(player)
	local stamina = humanClass.Stamina

	if humanClass.Legless then
		return
	end

	if active and stamina > 0 then
		humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
		stamina = math.clamp(stamina, 0, HumanConstants.MAX_STAMINA)
		humanClass.Sprinting = true
	else
		humanoid.WalkSpeed = HumanConstants.WALKSPEED
		humanClass.Sprinting = false
	end
end

Inputs.networker =
	Networker.new("InputNetwork", Inputs, { Inputs.ToggleSprint, Inputs.ApplyJumpDrain, Inputs.ApplyRollDrain })
return Inputs
