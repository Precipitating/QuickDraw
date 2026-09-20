local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local CoreGUIHandler = require(script.Parent.Parent.Utility.CoreGUIHandler)
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local GUIEffects = require(script.Parent.GUIEffects)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ShopGUIHandler = require(script.Parent.ShopGUIHandler)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local ToolsData = require(ReplicatedStorage.Shared.Classes.ToolsData)
local GamepassIds = require(ReplicatedStorage.Shared.GamepassIds)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local GUI = ReplicatedStorage.Shared.GUI
local InfoToolTip = nil

local DoctorGUIHandler = {}
DoctorGUIHandler.janitor = Janitor.new()

function DoctorGUIHandler:ConnectInformationToolTip(product: ImageButton)
	if not product then
		return
	end

	local data = ToolsData[product.Name]
	if not data then
		return
	end
	local desc = data.Description

	if not desc then
		return
	end

	local tooltipGUI = Utility.GetInstance(PlayerContext.PlayerGui, true, "ShopToolTipGUI")
	if not tooltipGUI then
		Utility.Warn("Missing ShopToolTipGUI screen gui")
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

	-- Hide GUI if died whilst this is frame is active
	PlayerContext.ActiveGUIs[tooltipGUI] = function()
		tooltip.Visible = false
	end

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
		InfoToolTip = tooltip
	end))
	self.janitor:Add(product.MouseLeave:Connect(function()
		task.defer(function()
			tooltipTxt.Text = ""
			tooltip.Visible = false
			if toolTipConn then
				toolTipConn:Disconnect()
			end
			InfoToolTip = nil
		end)
	end))
end

function DoctorGUIHandler:AddConfirmationGUI(productList, product)
	local exists = PlayerContext.PlayerGui:FindFirstChild("BuyConfirmationGUI")
	if exists then
		exists:Destroy()
	end
	local confirmGUI = GUI.BuyConfirmationGUI:Clone()
	local frame = confirmGUI:WaitForChild("ConfirmFrame", 3)
	local productName = product.Name
	-- get product price
	local productCost = 0

	if productList.Name == "HealList" then
		productCost = ToolsData[productName].Cost
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

	self.janitor:Add(yesButton.Activated:Once(function(_, _)
		local bought = ShopGUIHandler.networker:fetch("BuyItem", productName, productCost)

		if not bought then
			SoundManager.PlayKeyed("UI", "Error")
		else
			SoundManager.PlayKeyed("UI", "Purchase")
		end

		GUIEffects:PopOut(frame, function()
			confirmGUI:Destroy()
		end)
	end))

	self.janitor:Add(noButton.Activated:Once(function(_, _)
		GUIEffects:PopOut(frame, function()
			confirmGUI:Destroy()
		end)
	end))

	confirmGUI.Parent = PlayerContext.PlayerGui

	GUIEffects:PopIn(frame, 1, function()
		PlayerContext.ActiveGUIs[confirmGUI] = function()
			GUIEffects:PopOut(frame, function()
				confirmGUI:Destroy()
			end)
		end

		if InfoToolTip then
			InfoToolTip.Visible = false
		end
	end)
end

function DoctorGUIHandler:ConnectProductList(productList: ScrollingFrame)
	local children = productList:GetChildren()
	for _, product in children do
		if not product:isA("ImageButton") then
			continue
		end

		-- Apply  price
		local price: TextLabel = product:WaitForChild("Price", 10)
		if price then
			local data = ToolsData[product.Name]
			local medicalToolCostText = `{if data.Cost == 0 then "Free" else "$" .. data.Cost}`
			price.Text = if data and data.Cost then medicalToolCostText else "Error"
		end

		self:ConnectInformationToolTip(product)

		self.janitor:Add(product.Activated:Connect(function(_, _)
			self:AddConfirmationGUI(productList, product)
		end))
	end
end

function DoctorGUIHandler:ConnectRobuxList(robuxList: ScrollingFrame)
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

function DoctorGUIHandler:ConnectShopGUI(gui: ScreenGui, linkedPrompt: ProximityPrompt, exitAudioName: string)
	local bg: Frame = Utility.GetInstance(gui, true, "BG")

	if GUIEffects:IsPopOpenOrOpening(bg) then
		self:Disconnect(gui, exitAudioName, linkedPrompt)
		return
	end
	local exitButton: TextButton = Utility.GetInstance(gui, true, "BG", "Exit")
	local healingButton: TextButton = Utility.GetInstance(gui, true, "BG", "HealingButton")
	local robuxButton: TextButton = Utility.GetInstance(gui, true, "BG", "RobuxButton")
	local healAllButton: TextButton = Utility.GetInstance(gui, true, "BG", "HealAllButton")

	local healList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "HealList")
	local robuxList: ScrollingFrame = Utility.GetInstance(gui, true, "BG", "RobuxList")

	assert(bg, "Missing bg from DoctorGUI")
	assert(exitButton, "Missing exit button from DoctorGUI")
	assert(healingButton, "Missing healing button from DoctorGUI")
	assert(healAllButton, "Missing heal all button from DoctorGUI")
	assert(healList, "Missing heal list from DoctorGUI")

	linkedPrompt.Enabled = false
	PlayerContext.Humanoid:UnequipTools()
	repeat
		task.wait()
	until not PlayerContext.Character:FindFirstChildOfClass("Tool")

	healAllButton.Text = `FULL HEAL  <br/> <font color="#FFFFFF">$500</font>`

	CoreGUIHandler.ToggleBackpackVisibility(false)
	ClientUtility.ToggleControls(false)
	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)
	ShopGUIHandler.networker:fire("OnGUIOpen", linkedPrompt:FindFirstAncestorOfClass("Model"))

	self.janitor:Add(exitButton.Activated:Connect(function(_, _)
		self:Disconnect(gui, exitAudioName, linkedPrompt)
	end))

	self.janitor:Add(healingButton.Activated:Connect(function(_, _)
		healList.Visible = true
		robuxList.Visible = false
	end))

	self.janitor:Add(robuxButton.Activated:Connect(function(_, _)
		robuxList.Visible = true
		healList.Visible = false
	end))

	self.janitor:Add(healAllButton.Activated:Connect(function(_, _)
		local success = ShopGUIHandler.networker:fetch("HealPlayerFully")

		if success then
			SoundManager.PlayKeyed("Voiceline", "MedicBuy")
		else
			SoundManager.PlayKeyed("UI", "Error")
		end
	end))

	self:ConnectProductList(healList, healingButton)
	self:ConnectRobuxList(robuxList)

	GUIEffects:PopIn(bg, 1, function()
		-- If we die, disconnect automatically
		PlayerContext.ActiveGUIs[gui] = function()
			self:Disconnect(gui, exitAudioName, linkedPrompt)
		end
	end)
end

function DoctorGUIHandler:Disconnect(gui: ScreenGui, exitAudioName: string, linkedPrompt: ProximityPrompt)
	local bg = gui:WaitForChild("BG", 3)
	self.janitor:Cleanup()
	GUIEffects:PopOut(bg, function()
		gui:Destroy()
		if exitAudioName then
			SoundManager.PlayKeyed("Voiceline", exitAudioName)
		end
		PlayerContext.ApplyMouseLock(true)
		ClientUtility.ToggleControls(true)
		CrosshairHandler:ToggleCrosshairVisibility(false)
		CoreGUIHandler.ToggleBackpackVisibility(true)
		ShopGUIHandler.networker:fire("OnGUIClose")
		linkedPrompt.Enabled = true
		PlayerContext.ActiveGUIs[gui] = nil
		PlayerContext.IsBusy = false
	end)
end

return DoctorGUIHandler
