local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanNPC = require(ServerScriptService.Server.Classes.HumanNPC)
local HumanPlayer = require(ServerScriptService.Server.Classes.HumanPlayer)
type HumanPlayer = ClassTypes.HumanPlayer

local PlayerManager = {}
PlayerManager.HumanClasses = {}

function PlayerManager:AddHumanClass(player: Player)
	if not player then
		warn(`Attempting to add a Human class, but player is {player}`)
		return
	end
	local character = player.Character
	local humanoid = character:WaitForChild("Humanoid")
	self.HumanClasses[humanoid] = HumanPlayer.new(humanoid, player)

	return self.HumanClasses[humanoid]
end

function PlayerManager:AddHumanClassNPC(humanoid: Humanoid?)
	assert(humanoid, "[PlayerManager:AddHumanClassNPC] should be humanoid argument!")
	self.HumanClasses[humanoid] = HumanNPC.new(humanoid)
	return self.HumanClasses[humanoid]
end

function PlayerManager:RemoveHumanClass(humanoid: Humanoid?)
	local entry = self.HumanClasses[humanoid]
	if not entry then
		warn(`Can't remove player from class as it doesn't exist`)
		return
	end
	entry = nil

	print("Player removed from table!")
end

function PlayerManager:GetHumanClass(key: Humanoid)
	if not key then
		error(`GetHumanClass argument 'key' is invalid`)
		return
	end

	if not PlayerManager.HumanClasses[key] then
		print(self.HumanClasses[key])
		error(`Cannot get human class of {key}...`)

		return
	end

	local humanoidParent = key.Parent

	print(`Succesfully obtained human class reference of player {humanoidParent.Name}`)
	return self.HumanClasses[key]
end

return PlayerManager
