-- inheriting Human and defining Player only data
local Gun = require(script.Parent.Gun)
local Human = require(script.Parent.Human)
local HumanPlayer = setmetatable({}, Human)
HumanPlayer.__index = HumanPlayer

function HumanPlayer.new(humanoid: Humanoid, player: Player?)
	assert(player, "HumanPlayer constructor needs a valid player instance!")
	local self = setmetatable(Human.new(humanoid), HumanPlayer)
	self.Player = player
	self.HumanType = "Player"
	self.CurrentGun = Gun.new(self, player)
	self.CurrentGun:AddGunToInventory()

	print(`New Human class initialized for {self.Player.DisplayName}`)
	return self :: any
end

function HumanPlayer:OnDeath()
	self.Humanoid.Health = 0
end

return HumanPlayer
