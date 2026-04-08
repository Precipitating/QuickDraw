local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local ShopGUIHandler = {}
ShopGUIHandler.janitor = Janitor.new()

function ShopGUIHandler:ConnectShopGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt)
	local exitButton: TextButton = Utility.GetInstance(gui, true, "Exit")
	local throwablesButton: TextButton = Utility.GetInstance(gui, true, "BG", "ThrowablesButton")
	local weaponsButton: TextButton = Utility.GetInstance(gui, true, "BG", "WeaponsButton")

	local weaponsList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "WeaponsList")
	local throwablesList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "ThrowablesList")
	assert(exitButton, "Missing exit button from ShopGUI")
	assert(throwablesButton, "Missing throwables button from ShopGUI")
	assert(weaponsButton, "Missing weapons button from ShopGUI")
	assert(throwablesList, "Missing throwables list from ShopGUI")
	assert(weaponsList, "Missing weapons list from ShopGUI")

	linkedPrompt.Enabled = false
	PlayerContext.Humanoid:UnequipTools()
	task.wait(0.5)
	CoreGUIHandler.ToggleBackpackVisibility(false)
	ClientUtility.ToggleControls(false)
	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)

	self.janitor:Add(exitButton.Activated:Connect(function(_, _)
		self:Disconnect()
		gui:Destroy()
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		linkedPrompt.Enabled = true
	end))

	self.janitor:Add(throwablesButton.Activated:Connect(function(_, _)
		throwablesList.Visible = true
		weaponsList.Visible = false
	end))

	self.janitor:Add(weaponsButton.Activated:Connect(function(_, _)
		weaponsList.Visible = true
		throwablesList.Visible = false
	end))
end

function ShopGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return ShopGUIHandler
