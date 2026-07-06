local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local GUIEffects = require(script.Parent.GUIEffects)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ShopGUIHandler = require(script.Parent.ShopGUIHandler)
local GUI = ReplicatedStorage.Shared.GUI
local LootPickupGUIHandler = {}

local PICKUP_SOUNDS = {
	TombStone = "SandPickup",
	TumbleWeed = "TumbleWeedPickup",
}

function LootPickupGUIHandler:CloseGUI(confirmGUI: ScreenGui, confirmFrame: Frame)
	GUIEffects:PopOut(confirmFrame, function()
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		PlayerContext.ActiveGUIs[confirmGUI] = nil
		confirmGUI:Destroy()
		PlayerContext.IsBusy = false
	end)
end

function LootPickupGUIHandler:ConnectGUI(pickupType: string, chosenLoot: string)
	if not pickupType or not chosenLoot then
		warn("[LootPickupGUIHandler:ConnectGUI] Missing arguments")
		return
	end
	local confirmGUI = GUI.BuyConfirmationGUI
	confirmGUI = confirmGUI:Clone()

	local confirmFrame: Frame = Utility.GetInstance(confirmGUI, true, "ConfirmFrame")
	local confirmLabel: TextLabel = Utility.GetInstance(confirmFrame, true, "ConfirmLabel")
	local yesButton: TextButton = Utility.GetInstance(confirmFrame, true, "YesButton")
	local noButton: TextButton = Utility.GetInstance(confirmFrame, true, "NoButton")
	local pickupSound = PICKUP_SOUNDS[pickupType]

	if not confirmFrame or not confirmLabel or not yesButton or not noButton then
		return
	end

	confirmLabel.Text = `Rolled {chosenLoot}, do you want add this to your inventory?`

	yesButton.Activated:Once(function()
		ShopGUIHandler.networker:fetch("BuyItem", chosenLoot, 0, pickupSound)
		self:CloseGUI(confirmGUI, confirmFrame)
	end)

	noButton.Activated:Once(function()
		self:CloseGUI(confirmGUI, confirmFrame)
	end)

	confirmGUI.Parent = PlayerContext.PlayerGui
	CoreGUIHandler.ToggleBackpackVisibility(false)
	ClientUtility.ToggleControls(false)
	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)

	GUIEffects:PopIn(confirmFrame, 1, function()
		PlayerContext.ActiveGUIs[confirmGUI] = function()
			self:CloseGUI(confirmGUI, confirmFrame)
		end
	end)
end

return LootPickupGUIHandler
