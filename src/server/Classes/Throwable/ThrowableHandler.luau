local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = ClassTypes.Human
type Throwable = ClassTypes.Throwable

local ThrowableHandler = {}

function ThrowableHandler:ThrowProjectile(player: Player, cameraLookVector: Vector3)
	local character = player.Character
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		error("Missing humanoid to throw projectile")
		return false
	end

	local humanClass: Human = PlayerManager:GetHumanClass(humanoid)
	local throwable: Throwable? = humanClass.CurrentThrowable

	if not throwable then
		error("Throwable is nil!")
		return false
	end

	local success = throwable:Throw(cameraLookVector)

	if not success then
		print("Cooldown")
		return false
	end

	print("Thrown!")

	return true
end
ThrowableHandler.networker = Networker.new("ThrowableNetwork", ThrowableHandler, { ThrowableHandler.ThrowProjectile })
return ThrowableHandler
