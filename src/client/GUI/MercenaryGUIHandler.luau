local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Packages.DataService).client
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local MercenaryTemplate = ReplicatedStorage.Shared.GUI.MercenaryTarget
local BASE_COST = 1250

local MercenaryGUIHandler = {}
MercenaryGUIHandler.janitor = Janitor.new()
MercenaryGUIHandler.networker = Networker.new("MercenaryNetwork", MercenaryGUIHandler)

function MercenaryGUIHandler:ConnectMercenaryGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt)
	local bg: TextButton = Utility.GetInstance(gui, true, "BG")
	local frame: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "ScrollingFrame")
	local exitButton: TextButton = Utility.GetInstance(gui, true, "Exit")
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

	self.janitor:Add(exitButton.Activated:Connect(function(_, _)
		self:Disconnect()
		gui:Destroy()
		SoundManager.PlayKeyed("Voiceline", "MercExit")
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		self.networker:fire("OnGUIClose")
		linkedPrompt.Enabled = true
	end))
end

function MercenaryGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return MercenaryGUIHandler
