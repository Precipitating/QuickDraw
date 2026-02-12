local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Human = require(ReplicatedStorage.Shared.Classes.Human)

local PlayerManager = {}
PlayerManager.HumanClasses = {}

function PlayerManager:AddHumanClass(key: Player)
	if not key then
		warn(`Attempting to add a Human class, but key is {key}`)
		return
	end
	self.HumanClasses[key] = Human.FromPlayer(key)

	return self.HumanClasses[key]
end

function PlayerManager:GetHumanClass(key: Player)
	if not key then
		warn(`GetHumanClass argument 'key' is invalid`)
		return
	end

	if not PlayerManager[key] then
		warn(`Cannot get human class of {key}...`)
		return
	end

	print(`Succesfully obtained human class reference of player {key.DisplayName}`)
	return self.HumanClasses[key]
end

return PlayerManager
