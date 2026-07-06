local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local LootPickupGUIHandler = require(script.Parent.Parent.GUI.LootPickupGUIHandler)
local GUIEffects = require(script.Parent.Parent.GUI.GUIEffects)
local ClientDigHandler = require(script.Parent.Parent.Dig.ClientDigHandler)
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
		if PlayerContext.IsBusy then
			return
		end
		local shopGUI = nil
		if not CollectionService:HasTag(prompt, "Special") then
			if player.PlayerGui:FindFirstChild("ShopGUI") then
				return
			end
			shopGUI = GUI.ShopGUI:Clone()
			shopGUI.Parent = player.PlayerGui
			shopGUI.Enabled = true
			PlayerContext.IsBusy = true
			SoundManager.PlayKeyed("Voiceline", "ShopGreeting")
			ShopGUIHandler:ConnectShopGUI(shopGUI, prompt, "ShopExit")
		else
			if player.PlayerGui:FindFirstChild("SpecialShopGUI") then
				return
			end
			shopGUI = GUI.SpecialShopGUI:Clone()
			shopGUI.Parent = player.PlayerGui
			shopGUI.Enabled = true
			PlayerContext.IsBusy = true
			SoundManager.PlayKeyed("Voiceline", "SpecialShopGreeting")
			ShopGUIHandler:ConnectShopGUI(shopGUI, prompt, "SpecialShopExit")
		end
	end,
	["BankPrompt"] = function(player: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		if player.PlayerGui:FindFirstChild("BankGUI") then
			return
		end
		local bank = GUI.BankGUI:Clone()

		local bg = bank:WaitForChild("BG", 3)
		if not bg then
			warn("Missing BG from BankGUI")
			return
		end
		--
		bank.Parent = player.PlayerGui
		bank.Enabled = true
		PlayerContext.IsBusy = true

		GUIEffects:PopIn(bg, 1, function()
			SoundManager.PlayKeyed("Voiceline", "BankGreeting")
			BankGUIHandler:ConnectBankGUI(bank, prompt)
			PlayerContext.ActiveGUIs[bank] = function()
				BankGUIHandler:CloseGUI(bank, bg, prompt)
			end
		end)
	end,
	["MercenaryPrompt"] = function(player: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		if player.PlayerGui:FindFirstChild("MercenaryGUI") then
			return
		end
		local mercGUI = GUI.MercenaryGUI:Clone()
		--
		local bg = mercGUI:WaitForChild("BG", 3)
		if not bg then
			warn("Missing BG from MercenaryGUI")
			return
		end
		--
		mercGUI.Parent = player.PlayerGui
		mercGUI.Enabled = true
		PlayerContext.IsBusy = true
		GUIEffects:PopIn(bg, 1, function()
			SoundManager.PlayKeyed("Voiceline", "MercGreeting")
			MercenaryGUIHandler:ConnectMercenaryGUI(mercGUI, prompt)

			PlayerContext.ActiveGUIs[mercGUI] = function()
				MercenaryGUIHandler:CloseGUI(mercGUI, bg, prompt)
			end
		end)
	end,
	["CashPickupPrompt"] = function(_: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		ProximityPromptHandler.networker:fire("CashPickedUp", prompt)
	end,
	["MedicPrompt"] = function(_: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		ProximityPromptHandler.networker:fire("HealPlayer", prompt)
	end,
	["LootPrompt"] = function(_: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		ProximityPromptHandler.networker:fire("LootPickup", "TumbleWeed", prompt)
	end,
	["TombstonePrompt"] = function(_: Player, prompt: ProximityPrompt)
		if PlayerContext.IsBusy then
			return
		end
		prompt.Enabled = false
		PlayerContext.IsBusy = true
		ClientDigHandler:StartDigging()

		task.delay(5, function()
			ClientDigHandler:StopDigging()
			ProximityPromptHandler.networker:fire("LootPickup", "Tombstone", prompt)
		end)
	end,
}

function ProximityPromptHandler:ConnectLootPickupGUI(pickupType: string, chosenLoot: string)
	LootPickupGUIHandler:ConnectGUI(pickupType, chosenLoot)
end

function ProximityPromptHandler.Initialize()
	local function connectPrompt(tag, handler, prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.Triggered:Connect(function(player)
			if not PlayerContext.Humanoid or PlayerContext.Humanoid.Health <= 0 then
				return
			end

			if PlayerContext.Character and CollectionService:HasTag(PlayerContext.Character, "Dead") then
				return
			end
			handler(player, prompt)
		end)
	end

	for tag, handler in PROMPT_HANDLERS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(prompt)
			connectPrompt(tag, handler, prompt)
		end)

		for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
			connectPrompt(tag, handler, prompt)
		end
	end
end

return ProximityPromptHandler
