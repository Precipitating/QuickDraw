local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local ShopGUIHandler = require(script.Parent.Parent.GUI.ShopGUIHandler)
local GUI = ReplicatedStorage.Shared.GUI
local PROMPT_HANDLERS = {
	["ShopPrompt"] = function(player: Player, prompt: ProximityPrompt)
		local shop = GUI.ShopGUI:Clone()
		shop.Parent = player.PlayerGui
		shop.Enabled = true
		SoundManager.PlayKeyed("Voiceline", "ShopGreeting")
		ShopGUIHandler:ConnectShopGUI(shop, prompt)
	end,
}

local ProximityPromptHandler = {}

function ProximityPromptHandler.Initialize()
	for tag, handler in PROMPT_HANDLERS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(prompt)
			if not prompt:IsA("ProximityPrompt") then
				return
			end
			prompt.Triggered:Connect(function(player)
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
