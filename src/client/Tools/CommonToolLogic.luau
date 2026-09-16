local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)

local HOLD_TRIGGER_TIME = 0.5

local CommonToolLogic = {}

function CommonToolLogic:ConnectConsumableTool(tool: Tool, holdTime: number, toolData: any, onActivated: () -> ())
	if not tool then
		return
	end
	if not toolData then
		warn("Tool data doesn't exist")
		return
	end

	while not PlayerContext.PlayerGui do
		task.wait()
	end

	local holdGUI: ScreenGui = PlayerContext.PlayerGui:WaitForChild("PlaceGUI")
	if not holdGUI then
		warn("Missing HoldGUI")
		return
	end

	local holdGUIFill: Frame = Utility.GetInstance(holdGUI, true, "Frame", "Fill")
	local requiredHoldTime = holdTime or toolData.HoldTime

	-- Per-tool keys so setting up tool B doesn't tear down tool A's connections
	local toolId = RandomModule.GetRandomIntBetween(1, 9999)
	local innerKey = `InnerConsumableToolConn_{toolId}`
	local outerKey = `OuterConsumableToolConn_{toolId}`
	local destroyKey = `DestroyingConsumableToolConn_{toolId}`

	local function resetHoldState()
		ContextActionService:UnbindAction("LMBHeldAction")
		if holdGUI then
			holdGUI.Enabled = false
			if holdGUIFill then
				holdGUIFill.Size = UDim2.fromScale(0, 1)
			end
		end
	end

	-- Only clear THIS tool's previous setup, not every consumable tool's
	PlayerContext.janitor:Remove(innerKey)
	PlayerContext.janitor:Remove(outerKey)
	PlayerContext.janitor:Remove(destroyKey)

	PlayerContext.janitor:Add(
		tool.Equipped:Connect(function()
			warn("Tool connected: " .. tool.Name)

			local holdingLMBStart: number? = nil
			local holdingLMB = false

			ContextActionService:BindAction("LMBHeldAction", function(_, inputState, _)
				if inputState == Enum.UserInputState.Begin then
					holdingLMBStart = os.clock()
					holdingLMB = false
					holdGUI.Enabled = true
				elseif inputState == Enum.UserInputState.End then
					holdingLMBStart = nil
					holdingLMB = false
					holdGUI.Enabled = false
					holdGUIFill.Size = UDim2.fromScale(0, 1)
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)

			PlayerContext.janitor:Add(
				RunService.Heartbeat:Connect(function()
					if not holdingLMBStart then
						return
					end
					local curr = os.clock()
					local timeSinceHold = curr - holdingLMBStart
					if timeSinceHold >= HOLD_TRIGGER_TIME and not holdingLMB then
						holdingLMB = true
					end

					if timeSinceHold >= requiredHoldTime then
						onActivated()
						holdGUI.Enabled = false
						holdingLMB = false
						holdingLMBStart = nil
					else
						local barVal = math.min(timeSinceHold / requiredHoldTime, 1)
						holdGUIFill.Size = UDim2.fromScale(barVal, 1)
					end
				end),
				"Disconnect",
				innerKey
			)
		end),
		"Disconnect",
		outerKey
	)

	PlayerContext.janitor:Add(tool.Unequipped:Connect(function()
		warn("Tool disconnected: " .. tool.Name)
		PlayerContext.janitor:Remove(innerKey)
		resetHoldState()
	end))

	PlayerContext.janitor:Add(
		tool.Destroying:Connect(function()
			PlayerContext.janitor:Remove(innerKey)
			PlayerContext.janitor:Remove(outerKey)
			resetHoldState()
		end),
		"Disconnect",
		destroyKey
	)
end

return CommonToolLogic
