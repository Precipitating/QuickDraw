local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Player: Player = game.Players.LocalPlayer
local DataService = require(ReplicatedStorage.Packages.DataService).client

local ClientData = {}

function ClientData.Initialize()
	DataService:init()
	ClientData.WaitForData()
	Utility.Warn(`[Client data initialized]`)
end

function ClientData.InitializeCurrencyData()
	local CurrencyText = Player.PlayerGui:WaitForChild("CurrencyGUI"):WaitForChild("Currency")
	DataService:getChangedSignal("currency"):Connect(function(amt)
		SoundManager.PlayKeyed("UI", "AddMoney")
		CurrencyText.Text = `${amt}`
		warn(`{Player.Name} client update money! {amt}`)
	end)
	DataService:getChangedSignal("quests"):Connect(function(data)
		SoundManager.PlayKeyed("UI", "SmokeDetector")
	end)
	CurrencyText.Text = `${DataService:get("currency")}`
end
function ClientData.WaitForData()
	return DataService:waitForData()
end

return ClientData
