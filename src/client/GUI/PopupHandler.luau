local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local PopupImg = ReplicatedStorage.Shared.GUI.PopupImg
local PopupHandler = {}

PopupHandler.janitor = Janitor.new()
PopupHandler.networker = Networker.new("PopupNetwork", PopupHandler)

local function PopIn(uiScale: UIScale)
	local tween = TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	tween:Play()
end

local function PopOut(uiScale: UIScale)
	local tween = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0,
	})
	tween:Play()

	tween.Completed:Once(function()
		local parent = uiScale.Parent
		if parent then
			parent:Destroy()
		end
	end)
end

function PopupHandler:NewPopup(duration: number, text: string)
	local playerGUI = PlayerContext.PlayerGui
	if not playerGUI then
		warn("No popup, player gui ref missing")
		return
	end
	local newPopup = PopupImg:Clone()

	local textLabel: TextLabel = Utility.GetInstance(newPopup, true, "TextLabel")
	local imgScale: UIScale = Utility.GetInstance(newPopup, true, "UIScale")
	local textScale: UIScale = Utility.GetInstance(textLabel, true, "UIScale")

	assert(textLabel, "Missing new text label ref for popup GUI")
	assert(imgScale, "Missing new imgScale ref for popup GUI")
	assert(textScale, "Missing new textScale ref for popup GUI")

	textLabel.Text = text or "Error"
	newPopup.Parent = Utility.GetInstance(playerGUI, true, "PopupGUI")

	task.spawn(function()
		PopIn(imgScale)
		PopIn(textScale)
	end)

	task.delay(duration or 3, function()
		PopOut(imgScale)
		PopOut(textScale)
	end)
end

return PopupHandler
