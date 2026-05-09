local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local ShopGUIHandler = require(script.Parent.Parent.GUI.ShopGUIHandler)
local BankGUIHandler = require(script.Parent.Parent.GUI.BankGUIHandler)
local MercenaryGUIHandler = require(script.Parent.Parent.GUI.MercenaryGUIHandler)
local GUI = ReplicatedStorage.Shared.GUI
local ProximityPromptHandler = {}
ProximityPromptHandler.networker = Networker.new("ProximityPromptNetwork", ProximityPromptHandler)

local PROMPT_HANDLERS = {
	["ShopPrompt"] = function(player: Player, prompt: ProximityPrompt)
		local shop = GUI.ShopGUI:Clone()
		shop.Parent = player.PlayerGui
		shop.Enabled = true
		SoundManager.PlayKeyed("Voiceline", "ShopGreeting")
		ShopGUIHandler:ConnectShopGUI(shop, prompt)
	end,
	["BankPrompt"] = function(player: Player, prompt: ProximityPrompt)
		local bank = GUI.BankGUI:Clone()
		bank.Parent = player.PlayerGui
		bank.Enabled = true
		SoundManager.PlayKeyed("Voiceline", "BankGreeting")
		BankGUIHandler:ConnectBankGUI(bank, prompt)
	end,
	["MercenaryPrompt"] = function(player: Player, prompt: ProximityPrompt)
		local mercGUI = GUI.MercenaryGUI:Clone()
		mercGUI.Parent = player.PlayerGui
		mercGUI.Enabled = true
		SoundManager.PlayKeyed("Voiceline", "MercGreeting")
		MercenaryGUIHandler:ConnectMercenaryGUI(mercGUI, prompt)
	end,
	["CashPickupPrompt"] = function(_: Player, prompt: ProximityPrompt)
		ProximityPromptHandler.networker:fire("CashPickedUp", prompt)
	end,
}

function ProximityPromptHandler.Initialize()
	for tag, handler in PROMPT_HANDLERS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(prompt)
			if not prompt:IsA("ProximityPrompt") then
				return
			end
			prompt.Triggered:Connect(function(player)
				if not PlayerContext.Humanoid or PlayerContext.Humanoid.Health <= 0 then
					return
				end
				handler(player, prompt)
			end)
		end)

		for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
			if not prompt:IsA("ProximityPrompt") then
				return
			end
			prompt.Triggered:Connect(function(player)
				handler(player, prompt)
			end)
		end
	end
end

return ProximityPromptHandler
