local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local HoldingLMBStart = false
local HoldingLMB = false
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

	local holdGUI: ScreenGui = PlayerContext.PlayerGui and PlayerContext.PlayerGui:WaitForChild("PlaceGUI", 3)
	if not holdGUI then
		warn("Missing HoldGUI")
		return
	end

	local holdGUIFill: Frame = Utility.GetInstance(holdGUI, true, "Frame", "Fill")

	PlayerContext.janitor:Remove("InnerConsumableToolConn")
	PlayerContext.janitor:Remove("OuterConsumableToolConn")

	PlayerContext.janitor:Add(
		tool.Equipped:Connect(function()
			warn("Tool connected")

			ContextActionService:BindAction("LMBHeldAction", function(_, inputState, _)
				if inputState == Enum.UserInputState.Begin then
					HoldingLMBStart = os.clock()
					HoldingLMB = false
					holdGUI.Enabled = true
				elseif inputState == Enum.UserInputState.End then
					HoldingLMBStart = nil
					HoldingLMB = false
					if holdGUI then
						holdGUI.Enabled = false
						holdGUIFill.Size = UDim2.fromScale(0, 1)
					end
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)

			PlayerContext.janitor:Add(
				RunService.Heartbeat:Connect(function()
					if not HoldingLMBStart then
						return
					end
					local curr = os.clock()
					local timeSinceHold = curr - HoldingLMBStart
					if timeSinceHold >= HOLD_TRIGGER_TIME and not HoldingLMB then
						HoldingLMB = true
					end

					if timeSinceHold >= holdTime then
						onActivated()

						holdGUI.Enabled = false
						HoldingLMB = false
						HoldingLMBStart = nil
					else
						local barVal = math.min(timeSinceHold / toolData.HoldTime, 1)
						holdGUIFill.Size = UDim2.fromScale(barVal, 1)
					end
				end),
				"Disconnect",
				"InnerConsumableToolConn"
			)
		end),
		"Disconnect",
		"OuterConsumableToolConn"
	)

	PlayerContext.janitor:Add(tool.Unequipped:Connect(function()
		warn("Trap disconnected")
		PlayerContext.janitor:Remove("InnerConsumableToolConn")
		PlayerContext.janitor:Remove("OuterConsumableToolConn")
		ContextActionService:UnbindAction("LMBHeldAction")
		HoldingLMBStart = nil
		holdGUI.Enabled = false
		holdGUIFill.Size = UDim2.fromScale(0, 1)
		HoldingLMB = false
	end))

	tool.Destroying:Connect(function()
		PlayerContext.janitor:Remove("InnerConsumableToolConn")
		PlayerContext.janitor:Remove("OuterConsumableToolConn")
		ContextActionService:UnbindAction("LMBHeldAction")
		holdGUI.Enabled = false
		holdGUIFill.Size = UDim2.fromScale(0, 1)
		HoldingLMBStart = nil
		HoldingLMB = false
	end)
end

return CommonToolLogic
