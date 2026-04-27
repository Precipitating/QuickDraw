local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local BankGUIHandler = {}
BankGUIHandler.janitor = Janitor.new()
BankGUIHandler.networker = Networker.new("BankNetwork", BankGUIHandler)

function BankGUIHandler:ConnectBankGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt)
	local depositButton: TextButton = Utility.GetInstance(gui, true, "BG", "Deposit")
	local withdrawButton: TextButton = Utility.GetInstance(gui, true, "BG", "Withdraw")
	local exitButton: TextButton = Utility.GetInstance(gui, true, "Exit")
	local inputBox: TextButton = Utility.GetInstance(gui, true, "BG", "Input")

	assert(exitButton, "Missing exit button from BankGUI")
	assert(depositButton, "Missing depositButton from BankGUI")
	assert(withdrawButton, "Missing withdrawButton from BankGUI")
	assert(inputBox, "Missing input box from BankGUI")

	linkedPrompt.Enabled = false
	PlayerContext.Humanoid:UnequipTools()
	repeat
		task.wait()
	until not PlayerContext.Character:FindFirstChildOfClass("Tool")

	CoreGUIHandler.ToggleBackpackVisibility(false)
	ClientUtility.ToggleControls(false)
	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)

	self.janitor:Add(exitButton.Activated:Connect(function(_, _)
		self:Disconnect()
		gui:Destroy()
		--SoundManager.PlayKeyed("Voiceline", "BankExit")
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		linkedPrompt.Enabled = true
	end))

	self.janitor:Add(depositButton.Activated:Connect(function(_, _)
		local inputVal = tonumber(inputBox.Text)
		if inputVal then
			self.networker:fire("Deposit", inputVal)
		end
	end))

	self.janitor:Add(withdrawButton.Activated:Connect(function(_, _)
		local inputVal = tonumber(inputBox.Text)
		if inputVal then
			self.networker:fire("Withdraw", inputVal)
		end
	end))
end

function BankGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return BankGUIHandler
