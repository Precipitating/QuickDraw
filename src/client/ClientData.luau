local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Player: Player = game.Players.LocalPlayer
local DataService = require(ReplicatedStorage.Packages.DataService).client
local CurrencyText = Player.PlayerGui:WaitForChild("CurrencyGUI"):WaitForChild("Currency")
local ClientData = {}

function ClientData.Initialize()
	DataService:init()
	DataService:getChangedSignal("currency"):Connect(function(amt)
		SoundManager.PlayKeyed("UI", "AddMoney")
		CurrencyText.Text = `${amt}`
		warn(`{Player.Name} client update money! {amt}`)
	end)
	CurrencyText.Text = `${DataService:get("currency")}`
end

function ClientData.WaitForData()
	return DataService:waitForData()
end

return ClientData
