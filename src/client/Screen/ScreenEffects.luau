local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CameraShaker = require(ReplicatedStorage.Shared.Effects.CameraShaker)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ScreenEffects = {}
ScreenEffects.networker = Networker.new("ScreenEffectsNetwork", ScreenEffects)
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

function ScreenEffects:ApplyOneShotEffect(effectName: string)
	PlayerContext.CameraShaker:Shake(CameraShaker.Presets[effectName])
end
function ScreenEffects:StartSustainEffect(effectName: string)
	PlayerContext.CameraShaker:ShakeSustain(CameraShaker.Presets[effectName])
end
function ScreenEffects:StopAllSustainEffects(fadeOut: number)
	PlayerContext.CameraShaker:StopSustained(fadeOut)
end

return ScreenEffects
