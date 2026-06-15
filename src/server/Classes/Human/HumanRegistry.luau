local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

local HumanRegistry = {}
HumanRegistry.HumanClasses = {}

function HumanRegistry:Add(humanoid: Humanoid, humanClass: ClassTypes.Human)
	self.HumanClasses[humanoid] = humanClass
	return humanClass
end

function HumanRegistry:Remove(humanoid: Humanoid)
	if not self.HumanClasses[humanoid] then
		warn(`Can't remove player from table as it doesn't exist`)
		return
	end
	self.HumanClasses[humanoid] = nil
end

function HumanRegistry:Get(humanoid: Humanoid?)
	if not humanoid then
		warn(`Get argument 'humanoid' is invalid`)
		return
	end
	if not self.HumanClasses[humanoid] then
		warn(`Get invalid key`)
		return
	end
	return self.HumanClasses[humanoid]
end

function HumanRegistry:GetFromPlayer(player: Player)
	if not player then
		return
	end
	local character = player.Character
	local humanoid: Humanoid? = Utility.GetInstance(character, false, "Humanoid")

	if not humanoid then
		warn("[HumanRegistry:GetFromPlayer] Humanoid is nil")
		return
	end
	local humanClass = self:Get(humanoid)
	if not humanClass then
		warn("[HumanRegistry:GetFromPlayer] Reference to humanClass is nil, probably died")
		return
	end
	return humanClass, humanoid
end

return HumanRegistry
