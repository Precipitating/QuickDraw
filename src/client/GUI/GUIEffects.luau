local TweenService = game:GetService("TweenService")
local GUIEffects = {}
local PopInInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PopOutInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local ActiveTweens = {}

local function InterruptActiveTween(parent, target: string)
	-- Look inside the sub-table to find and cancel the specific tween type
	if ActiveTweens[parent] and ActiveTweens[parent][target] then
		ActiveTweens[parent][target]:Cancel()
		ActiveTweens[parent][target] = nil
	end
end
function GUIEffects.GetActiveTweens(parent: any)
	return ActiveTweens[parent]
end

function GUIEffects:IsPopOpenOrOpening(parent: any): boolean
	if not parent then
		warn("Cannot pop in, parent ref is nil")
		return false
	end

	-- 1. Check if a PopIn tween is actively running right now
	local hasActivePopIn = ActiveTweens[parent] and ActiveTweens[parent].PopIn ~= nil

	-- 2. Check if it's physically visible and NOT currently shrinking
	local isStaticOpen = parent.Visible and not (ActiveTweens[parent] and ActiveTweens[parent].PopOut ~= nil)

	-- Return true if it's either growing or already fully open
	return hasActivePopIn or isStaticOpen
end

function GUIEffects:PopIn(parent: any, targetSize: number, onComplete: () -> ()?)
	if not parent then
		return
	end
	local uiScale: UIScale = parent:FindFirstChildOfClass("UIScale")
	if not uiScale then
		return
	end

	-- 1. Initialize the sub-table safely if it doesn't exist yet
	if not ActiveTweens[parent] then
		ActiveTweens[parent] = {}
	end

	-- 2. Cancel any running PopOut before we show the frame
	InterruptActiveTween(parent, "PopOut")
	parent.Visible = true

	local tweenPopIn: Tween = TweenService:Create(uiScale, PopInInfo, { Scale = targetSize })

	ActiveTweens[parent].PopIn = tweenPopIn
	tweenPopIn:Play()

	tweenPopIn.Completed:Once(function(playbackState)
		if
			playbackState == Enum.PlaybackState.Completed
			and ActiveTweens[parent]
			and ActiveTweens[parent].PopIn == tweenPopIn
		then
			ActiveTweens[parent].PopIn = nil
			if onComplete then
				onComplete()
			end
		end
	end)
end

function GUIEffects:PopOut(parent: any, onComplete: () -> ()?)
	if not parent then
		return
	end
	local uiScale = parent:FindFirstChildOfClass("UIScale")
	if not uiScale then
		return
	end

	if not ActiveTweens[parent] then
		ActiveTweens[parent] = {}
	end

	-- 1. Cancel any running PopIn before we shrink
	InterruptActiveTween(parent, "PopIn")

	local tweenPopOut = TweenService:Create(uiScale, PopOutInfo, { Scale = 0 })

	ActiveTweens[parent].PopOut = tweenPopOut
	tweenPopOut:Play()

	tweenPopOut.Completed:Once(function(playbackState)
		if
			playbackState == Enum.PlaybackState.Completed
			and ActiveTweens[parent]
			and ActiveTweens[parent].PopOut == tweenPopOut
		then
			ActiveTweens[parent].PopOut = nil
			parent.Visible = false
			if onComplete then
				onComplete()
			end
		end
	end)
end

return GUIEffects
