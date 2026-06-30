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

local BankGUIHandler = {}
BankGUIHandler.janitor = Janitor.new()
BankGUIHandler.networker = Networker.new("BankNetwork", BankGUIHandler)

function BankGUIHandler:DisplayBankBalance(currencyOwned: TextLabel?)
	if not currencyOwned then
		return
	end
	local bal = self.networker:fetch("GetBankBalance")

	if bal then
		currencyOwned.Text = `IN BANK: ${bal}`
	end
end

function BankGUIHandler:CloseGUI(gui: ScreenGui, bg: Frame, linkedPrompt: ProximityPrompt)
	GUIEffects:PopOut(bg, function()
		self:Disconnect()
		gui:Destroy()
		SoundManager.PlayKeyed("Voiceline", "BankExit")
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		self.networker:fire("OnGUIClose")
		linkedPrompt.Enabled = true
	end)
end

function BankGUIHandler:ConnectBankGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt)
	local bg: Frame = Utility.GetInstance(gui, true, "BG")
	local depositButton: TextButton = Utility.GetInstance(bg, true, "Deposit")
	local withdrawButton: TextButton = Utility.GetInstance(bg, true, "Withdraw")
	local exitButton: TextButton = Utility.GetInstance(bg, true, "Exit")
	local inputBox: TextButton = Utility.GetInstance(bg, true, "Input")
	local currencyOwned: TextLabel = Utility.GetInstance(bg, true, "CurrencyOwned")

	assert(bg, "Missing bg from BankGUI")
	assert(exitButton, "Missing exit button from BankGUI")
	assert(depositButton, "Missing depositButton from BankGUI")
	assert(withdrawButton, "Missing withdrawButton from BankGUI")
	assert(inputBox, "Missing input box from BankGUI")
	assert(currencyOwned, "Missing currencyOwned from BankGUI")

	self:DisplayBankBalance(currencyOwned)

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

	self.janitor:Add(exitButton.Activated:Connect(function(_, _)
		self:CloseGUI(gui, bg, linkedPrompt)
	end))

	self.janitor:Add(depositButton.Activated:Connect(function(_, _)
		local inputVal = tonumber(inputBox.Text)
		if inputVal then
			local success = self.networker:fetch("Deposit", inputVal)

			if success then
				self:DisplayBankBalance(currencyOwned)
				inputBox.Text = ""
			end
		end
	end))

	self.janitor:Add(withdrawButton.Activated:Connect(function(_, _)
		local inputVal = tonumber(inputBox.Text)
		if inputVal then
			local success = self.networker:fetch("Withdraw", inputVal)

			if success then
				self:DisplayBankBalance(currencyOwned)
				inputBox.Text = ""
			end
		end
	end))
end

function BankGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return BankGUIHandler
