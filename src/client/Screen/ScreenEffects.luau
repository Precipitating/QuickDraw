local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CameraShaker = require(ReplicatedStorage.Shared.Effects.CameraShaker)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)
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

function ScreenEffects:ApplyOneShotEffect(buf: { EffectName: string } | string)
	local data = {}
	if typeof(buf) == "buffer" then
		data = Sera.Deserialize(SeraSchemas.ScreenEffectsSchema, buf)
	else
		data.EffectName = buf
	end
	PlayerContext.CameraShaker:Shake(CameraShaker.Presets[data.EffectName])
end
function ScreenEffects:StartSustainEffect(buf)
	local data = Sera.Deserialize(SeraSchemas.ScreenEffectsSchema, buf)
	PlayerContext.CameraShaker:ShakeSustain(CameraShaker.Presets[data.EffectName])
end
function ScreenEffects:StopAllSustainEffects(fadeOut: number)
	PlayerContext.CameraShaker:StopSustained(fadeOut)
end

return ScreenEffects
