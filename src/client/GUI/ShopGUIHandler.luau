local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)
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
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local GUI = ReplicatedStorage.Shared.GUI

local ShopGUIHandler = {}
ShopGUIHandler.janitor = Janitor.new()
ShopGUIHandler.networker = Networker.new("ShopNetwork", ShopGUIHandler)

local function UpdateRefillPrice(refillButton: TextButton?)
	if not refillButton then
		return
	end
	local currentGunName = HumanNetwork.networker:fetch("GetCurrentGunName")
	if currentGunName then
		if currentGunName == "Revolver" then
			refillButton.Text = `REFILL AMMO  <br/> <font color="#FFFFFF">FREE </font>`
		else
			refillButton.Text = `REFILL AMMO  <br/> <font color="#FFFFFF">${GunData[currentGunName].RefillCost}</font>`
		end
	end
end

function ShopGUIHandler:ConnectInformationToolTip(product: ImageButton)
	if not product then
		return
	end

	local data = GunData[product.Name] or ThrowableData[product.Name] or TrapData[product.Name]
	if not data then
		return
	end
	local desc = data.Description

	if not desc then
		return
	end

	local tooltip: Frame? = Utility.GetInstance(PlayerContext.PlayerGui, true, "ShopToolTipGUI", "ShopToolTip")

	if not tooltip then
		return
	end

	local tooltipTxt: TextLabel? = Utility.GetInstance(tooltip, true, "TextLabel")

	if not tooltipTxt then
		return
	end

	local toolTipConn = nil

	local mouse = PlayerContext.Player:GetMouse()

	self.janitor:Add(product.MouseEnter:Connect(function()
		tooltipTxt.Text = desc

		-- tooltip follow mouse pos
		if toolTipConn then
			toolTipConn:Disconnect()
		end

		toolTipConn = RunService.RenderStepped:Connect(function()
			tooltip.Position = UDim2.fromOffset(mouse.X + 20, mouse.Y)
		end)

		tooltip.Visible = true
	end))
	self.janitor:Add(product.MouseLeave:Connect(function()
		task.defer(function()
			tooltipTxt.Text = ""
			tooltip.Visible = false
			if toolTipConn then
				toolTipConn:Disconnect()
			end
		end)
	end))
end

-- If refillAmmoButton is passed, it means we need to reupdate refill ammo cost when we buy the product type.
function ShopGUIHandler:ConnectProductList(productList: ScrollingFrame, refillAmmoButton: TextButton?)
	local children = productList:GetChildren()
	for _, product in children do
		if not product:isA("ImageButton") then
			continue
		end

		-- Apply correct price dynamically (visual side)
		local price: TextLabel = product:WaitForChild("Price", 10)
		if price then
			if productList.Name == "WeaponsList" then
				local gunCostText =
					`{if GunData[product.Name].Cost == 0 then "Free" else "$" .. GunData[product.Name].Cost} `
				price.Text = if GunData[product.Name] and GunData[product.Name].Cost then gunCostText else "Error"
			else
				local data = ThrowableData[product.Name] or TrapData[product.Name]
				local throwableCostText = `{if data.Cost == 0 then "Free" else "$" .. data.Cost}`
				price.Text = if data and data.Cost then throwableCostText else "Error"
			end
		end

		self:ConnectInformationToolTip(product)

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
			elseif productList.Name == "TrapsList" then
				productCost = TrapData[productName].Cost
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
					UpdateRefillPrice(refillAmmoButton)
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
	local trapsButton: TextButton = Utility.GetInstance(gui, true, "BG", "TrapsButton")
	local robuxButton: TextButton = Utility.GetInstance(gui, true, "BG", "RobuxButton")
	local refillAmmoButton: TextButton = Utility.GetInstance(gui, true, "BG", "AmmoRefillButton")

	local weaponsList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "WeaponsList")
	local throwablesList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "ThrowablesList")
	local trapsList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "TrapsList")
	local robuxList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "RobuxList")

	assert(exitButton, "Missing exit button from ShopGUI")
	assert(refillAmmoButton, "Missing ammo refill button from ShopGUI")
	assert(throwablesButton, "Missing throwables button from ShopGUI")
	assert(weaponsButton, "Missing weapons button from ShopGUI")
	assert(trapsButton, "Missing traps button from ShopGUI")
	assert(throwablesList, "Missing throwables list from ShopGUI")
	assert(weaponsList, "Missing weapons list from ShopGUI")
	assert(trapsList, "Missing traps list  from ShopGUI")

	linkedPrompt.Enabled = false
	PlayerContext.Humanoid:UnequipTools()
	repeat
		task.wait()
	until not PlayerContext.Character:FindFirstChildOfClass("Tool")

	UpdateRefillPrice(refillAmmoButton)

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
		trapsList.Visible = false
	end))

	self.janitor:Add(weaponsButton.Activated:Connect(function(_, _)
		weaponsList.Visible = true
		throwablesList.Visible = false
		robuxList.Visible = false
		trapsList.Visible = false
	end))

	self.janitor:Add(trapsButton.Activated:Connect(function(_, _)
		trapsList.Visible = true
		throwablesList.Visible = false
		robuxList.Visible = false
		weaponsList.Visible = false
	end))

	self.janitor:Add(robuxButton.Activated:Connect(function(_, _)
		robuxList.Visible = true
		throwablesList.Visible = false
		weaponsList.Visible = false
		trapsList.Visible = false
	end))

	self.janitor:Add(refillAmmoButton.Activated:Connect(function(_, _)
		local bought = self.networker:fetch("BuyRefillAmmo")

		if not bought then
			SoundManager.PlayKeyed("UI", "Error")
		else
			SoundManager.PlayKeyed("UI", "Purchase")
		end
	end))

	self:ConnectProductList(weaponsList, refillAmmoButton)
	self:ConnectProductList(throwablesList, refillAmmoButton)
	self:ConnectProductList(trapsList, refillAmmoButton)
	self:ConnectRobuxList(robuxList)
end

function ShopGUIHandler:Disconnect()
	self.janitor:Cleanup()
end

return ShopGUIHandler
