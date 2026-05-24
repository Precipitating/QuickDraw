local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = ClassTypes.Human
type Throwable = ClassTypes.Throwable

local ThrowableHandler = {}

function ThrowableHandler:GetAmmo(player: Player)
	local humanClass: Human = PlayerManager:GetHumanClassFromPlayer(player)
	local throwable: Throwable? = humanClass.Inventory:GetThrowable()

	if not throwable then
		warn("Throwable is nil!")
		return nil
	end

	return throwable.CurrentAmmo
end

function ThrowableHandler:OnClientThrow(player: Player)
	local humanClass: Human = PlayerManager:GetHumanClassFromPlayer(player)
	local throwable: Throwable? = humanClass.Inventory:GetThrowable()

	if not throwable then
		warn("Throwable is nil!")
		return
	end

	-- removes from inventory if none left
	throwable:UpdateAmmo(-1)
end

ThrowableHandler.networker =
	Networker.new("ThrowableNetwork", ThrowableHandler, { ThrowableHandler.GetAmmo, ThrowableHandler.OnClientThrow })
return ThrowableHandler
