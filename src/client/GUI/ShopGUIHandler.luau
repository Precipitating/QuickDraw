local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local GamepassIds = require(ReplicatedStorage.Shared.GamepassIds)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local GUI = ReplicatedStorage.Shared.GUI

local ShopGUIHandler = {}
ShopGUIHandler.janitor = Janitor.new()
ShopGUIHandler.networker = Networker.new("ShopNetwork", ShopGUIHandler)

function ShopGUIHandler:ConnectProductList(productList: ScrollingFrame)
	local children = productList:GetChildren()
	for _, product in children do
		if not product:isA("ImageButton") then
			continue
		end
		self.janitor:Add(product.Activated:Connect(function(_, _)
			local exists = PlayerContext.PlayerGui:FindFirstChild("BuyConfirmationGUI")
			if exists then
				exists:Destroy()
			end
			local confirmGUI = GUI.BuyConfirmationGUI:Clone()
			local productName = product.Name
			-- get product price
			local productCost = 0
			if productList.Name == "WeaponsList" then
				productCost = GunData[productName].Cost
			elseif productList.Name == "ThrowablesList" then
				productCost = ThrowableData[productName].Cost
			end
			productCost = tostring(productCost)

			-- connect the gui up
			local yesButton = Utility.GetInstance(confirmGUI, true, "ConfirmFrame", "YesButton")
			assert(yesButton, "Missing yes button reference on confirmGUI")
			local noButton = Utility.GetInstance(confirmGUI, true, "ConfirmFrame", "NoButton")
			assert(noButton, "Missing no button reference on confirmGUI")
			local confirmText = Utility.GetInstance(confirmGUI, true, "ConfirmFrame", "ConfirmLabel")
			assert(confirmText, "Missing confirm label reference on confirmGUI")
			confirmText.Text = `Do you want to buy {productName} for ${productCost}?`

			yesButton.Activated:Connect(function(_, _)
				local bought = self.networker:fetch("BuyItem", productName, productCost)
				confirmGUI:Destroy()

				if not bought then
					SoundManager.PlayKeyed("UI", "Error")
				else
					SoundManager.PlayKeyed("UI", "Purchase")
				end
			end)

			noButton.Activated:Connect(function(_, _)
				confirmGUI:Destroy()
			end)

			confirmGUI.Parent = PlayerContext.PlayerGui
		end))
	end
end

function ShopGUIHandler:ConnectRobuxList(robuxList: ScrollingFrame)
	local children = robuxList:GetChildren()

	for _, btn: TextButton in children do
		if not btn:IsA("TextButton") then
			continue
		end
		btn.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(PlayerContext.Player, GamepassIds[btn.Name])
		end)
	end
end

function ShopGUIHandler:ConnectShopGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt, exitAudioName: string)
	local exitButton: TextButton = Utility.GetInstance(gui, true, "Exit")
	local throwablesButton: TextButton = Utility.GetInstance(gui, true, "BG", "ThrowablesButton")
	local weaponsButton: TextButton = Utility.GetInstance(gui, true, "BG", "WeaponsButton")
	local robuxButton: TextButton = Utility.GetInstance(gui, true, "BG", "RobuxButton")
	local refillAmmoButton: TextButton = Utility.GetInstance(gui, true, "BG", "AmmoRefillButton")

	local weaponsList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "WeaponsList")
	local throwablesList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "ThrowablesList")
	local robuxList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "RobuxList")

	assert(exitButton, "Missing exit button from ShopGUI")
	assert(refillAmmoButton, "Missing ammo refill button from ShopGUI")
	assert(throwablesButton, "Missing throwables button from ShopGUI")
	assert(weaponsButton, "Missing weapons button from ShopGUI")
	assert(throwablesList, "Missing throwables list from ShopGUI")
	assert(weaponsList, "Missing weapons list from ShopGUI")

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
		self:Disconnect()
		gui:Destroy()
		if exitAudioName then
			SoundManager.PlayKeyed("Voiceline", exitAudioName)
		end
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		self.networker:fire("OnGUIClose")
		linkedPrompt.Enabled = true
	end))

	self.janitor:Add(throwablesButton.Activated:Connect(function(_, _)
		throwablesList.Visible = true
		weaponsList.Visible = false
		robuxList.Visible = false
	end))

	self.janitor:Add(weaponsButton.Activated:Connect(function(_, _)
		weaponsList.Visible = true
		throwablesList.Visible = false
		robuxList.Visible = false
	end))
	self.janitor:Add(refillAmmoButton.Activated:Connect(function(_, _)
		local bought = self.networker:fetch("BuyRefillAmmo")
		if not bought then
			SoundManager.PlayKeyed("UI", "Error")
		else
			SoundManager.PlayKeyed("UI", "Purchase")
		end
	end))

	self.janitor:Add(robuxButton.Activated:Connect(function(_, _)
		robuxList.Visible = true
		throwablesList.Visible = false
		weaponsList.Visible = false
	end))

	self:ConnectProductList(weaponsList)
	self:ConnectProductList(throwablesList)
	self:ConnectRobuxList(robuxList)
end

function ShopGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return ShopGUIHandler
