local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)

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

	if not humanClass or humanClass.Legless or not humanClass.Humanoid then
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

function Inputs:ApplyKickDrain(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or humanClass.Legless or not humanClass.Humanoid then
		return false
	end

	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end
	if humanClass.Stamina < HumanConstants.KICK_DRAIN then
		return false
	end

	humanClass.KickSignalled = true
	humanClass:ApplyKickForce()

	return true
end

function Inputs:ToggleSprint(player: Player, active: boolean)
	local humanClass, humanoid = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or not humanClass.Stamina then
		return
	end
	local stamina = humanClass.Stamina
	if humanClass.Legless then
		return
	end

	local inventory = humanClass and humanClass.Inventory
	local gun = inventory and inventory:GetGun()
	local isHoldingGun = gun and gun.HoldingGun
	local sprintSpeed = if isHoldingGun
		then HumanConstants.SPRINT_SPEED * gun.EquipWalkspeedMultiplier
		else HumanConstants.SPRINT_SPEED
	local walkSpeed = if isHoldingGun
		then HumanConstants.WALKSPEED * gun.EquipWalkspeedMultiplier
		else HumanConstants.WALKSPEED

	if active and stamina and stamina > 0 then
		humanoid.WalkSpeed = sprintSpeed
		stamina = math.clamp(stamina, 0, HumanConstants.MAX_STAMINA)
		humanClass.Sprinting = true
	else
		humanoid.WalkSpeed = walkSpeed
		humanClass.Sprinting = false
	end
end

Inputs.networker = Networker.new(
	"InputNetwork",
	Inputs,
	{ Inputs.ToggleSprint, Inputs.ApplyJumpDrain, Inputs.ApplyRollDrain, Inputs.ApplyKickDrain }
)
return Inputs
