local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local GUIEffects = require(script.Parent.GUIEffects)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local MercenaryTemplate = ReplicatedStorage.Shared.GUI.MercenaryTarget

local MercenaryGUIHandler = {}
MercenaryGUIHandler.janitor = Janitor.new()
MercenaryGUIHandler.networker = Networker.new("MercenaryNetwork", MercenaryGUIHandler)

function MercenaryGUIHandler:CloseGUI(gui: ScreenGui, bg: Frame, linkedPrompt: ProximityPrompt)
	if not gui or not bg or not linkedPrompt then
		return
	end

	SoundManager.PlayKeyed("Voiceline", "MercExit")
	GUIEffects:PopOut(bg, function()
		self:Disconnect()
		gui:Destroy()

		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		self.networker:fire("OnGUIClose")
		linkedPrompt.Enabled = true
		PlayerContext.IsBusy = false
	end)
end

function MercenaryGUIHandler:ConnectMercenaryGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt)
	local bg: TextButton = Utility.GetInstance(gui, true, "BG")
	local frame: ScrollingFrame = Utility.GetInstance(bg, true, "ScrollingFrame")
	local exitButton: TextButton = Utility.GetInstance(bg, true, "Exit")
	assert(bg, "Missing bg from MercenaryGUI")
	assert(frame, "Missing frame from MercenaryGUI")
	assert(exitButton, "Missing exitButton from MercenaryGUI")

	linkedPrompt.Enabled = false
	PlayerContext.Humanoid:UnequipTools()
	repeat
		task.wait()
	until not PlayerContext.Character:FindFirstChildOfClass("Tool")

	CoreGUIHandler.ToggleBackpackVisibility(false)
	ClientUtility.ToggleControls(false)
	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)
	self.networker:fire("OnGUIOpen", linkedPrompt:FindFirstAncestorOfClass("Model"))

	local playerList = Players:GetPlayers()

	-- Connect each product to allow buy event to occur every click
	for _, target in playerList do
		local mercenaryTarget = MercenaryTemplate:Clone()
		local targetTextBox = Utility.GetInstance(mercenaryTarget, true, "TextLabel")
		local targetTextButton = Utility.GetInstance(mercenaryTarget, true, "TextButton")

		targetTextBox.Text = target.Name

		local targetCost = self.networker:fetch("GetTargetCost")
		targetTextButton.Text = `${targetCost}`

		mercenaryTarget.Parent = frame

		self.janitor:Add(targetTextButton.Activated:Connect(function(_, _)
			local success = self.networker:fetch("BuyTarget", target, targetCost)
			if success then
				SoundManager.PlayKeyed("Voiceline", "MercBuy")
			end
		end))
	end

	-- Exit GUI
	self.janitor:Add(exitButton.Activated:Once(function(_, _)
		self:CloseGUI(gui, bg, linkedPrompt)
	end))
end

function MercenaryGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return MercenaryGUIHandler
