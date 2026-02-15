-- inheriting Human and defining Player only data
local Gun = require(script.Parent.Gun)
local Human = require(script.Parent.Human)
local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new(self, self.Character)

	print(`New human class initiated for NPC {self.Character.Name}`)
	return self :: any
end

return HumanNPC
