local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local PopupGUI = {}

function PopupGUI:NewPopup(player: Player, duration: number, text: string)
	self.networker:fire(player, "NewPopup", duration, text)
end

PopupGUI.networker = Networker.new("PopupNetwork", PopupGUI)

return PopupGUI
