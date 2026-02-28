local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Human = require(script.Parent.Human)

local HumanSignals = require(script.Parent.HumanSignals)
local HumanPlayer = setmetatable({}, Human)
HumanPlayer.__index = HumanPlayer

function HumanPlayer.new(humanoid: Humanoid, player: Player?)
	assert(player, "HumanPlayer constructor needs a valid player instance!")
	local self = setmetatable(Human.new(humanoid), HumanPlayer)
	self.Player = player
	self.HumanType = "Player"
	self.CurrentGun = Gun.new("Revolver", self, player)
	self.CurrentGun:AddGunToInventory()
	self.BodyParts["RightUpperArm"]:SetNetworkOwner(player)

	print(`New Human class initialized for {self.Player.DisplayName}`)
	return self :: any
end

function HumanPlayer:ConnectGUIs()
	HumanSignals.ConnectHumanGUIs:Fire(self.Player, self.Humanoid)
end

-- scale gray screen tint on client via current health
function HumanPlayer:AdjustGrayscale()
	local hpPercent = self:GetHealthPercentage()
	HumanSignals.AdjustGrayscale:Fire(self.Player, -1 - -hpPercent)
end
return HumanPlayer
