local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ScreenEffects = {}
local ScreenEffectsJanitor = Janitor.new()

function ScreenEffects:ToggleBlackScreen(transparency: number, tweenDuration: number?)
	local frame = Utility.GetInstance(PlayerContext.PlayerGui, true, "BlackScreen", "Frame")
	if not frame then
		return
	end

	if not transparency or not tweenDuration then
		return
	end

	local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(frame, tweenInfo, {
		BackgroundTransparency = transparency,
	})

	ScreenEffectsJanitor:Add(fadeTween, "Destroy", "BlackScreenConn")
	fadeTween:Play()
end

return ScreenEffects
