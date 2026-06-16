local ContextActionService = game:GetService("ContextActionService")
local PlacesService = game:GetService("PlacesService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local PopupHandler = require(script.Parent.Parent.GUI.PopupHandler)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientTrapHandler = {}

ClientTrapHandler.networker = Networker.new("TrapNetwork", ClientTrapHandler)
local InnerTrapJanitor = Janitor.new()
local OuterTrapJanitor = Janitor.new()
local HOLD_TRIGGER_TIME = 0.5
local HoldingLMBStart = false
local HoldingLMB = false

local function PlaceDownTrap(trap: Tool?, placeSoundName: string)
	local thrown = false
	local humanoid: Humanoid = PlayerContext.Humanoid
	if not humanoid or not trap then
		return false
	end
	local humanoidState = humanoid:GetState()
	if humanoidState ~= Enum.HumanoidStateType.Running then
		return false
	end

	humanoid.WalkSpeed = 0

	local placeAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("PlaceDownTrap")
	local placeMarkerConn = placeAnim:GetMarkerReachedSignal("Placed"):Once(function()
		if humanoid.Health >= 0 then
			local placed = ClientTrapHandler.networker:fetch("PlaceDownTrap", trap)

			if not placed then
				PopupHandler:NewPopup(2, "Cannot place trap, invalid floor or no floor found")
				SoundManager.PlayKeyed("SFX", "Error")
				return
			end
			SoundManager.PlayKeyed("SFX", placeSoundName)
			thrown = placed
		end
	end)

	--
	placeAnim.Stopped:Once(function()
		if placeMarkerConn then
			placeMarkerConn:Disconnect()
		end

		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed = 6
		end
	end)

	return thrown
end

function ClientTrapHandler:ConnectTrap(trap: Tool?)
	if not trap then
		return
	end

	local trapData = TrapData[trap.Name]
	if not trapData then
		warn("Trap data doesn't exist for this tool!")
		return
	end
	local player = Players.LocalPlayer

	local holdGUI: ScreenGui = player.PlayerGui:WaitForChild("PlaceGUI", 3)
	if not holdGUI then
		warn("Missing HoldGUI")
		return
	end

	local holdGUIFill: Frame = Utility.GetInstance(holdGUI, true, "Frame", "Fill")

	InnerTrapJanitor:Cleanup()
	OuterTrapJanitor:Cleanup()

	OuterTrapJanitor:Add(trap.Equipped:Connect(function()
		warn("Trap connected")

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

		InnerTrapJanitor:Add(RunService.Heartbeat:Connect(function()
			if not HoldingLMBStart then
				return
			end
			local curr = os.clock()
			local timeSinceHold = curr - HoldingLMBStart
			if timeSinceHold >= HOLD_TRIGGER_TIME and not HoldingLMB then
				HoldingLMB = true
			end

			if timeSinceHold >= trapData.HoldTime then
				PlaceDownTrap(trap, trapData.PlaceSoundName)

				holdGUI.Enabled = false
				HoldingLMB = false
				HoldingLMBStart = nil
			else
				local barVal = math.min(timeSinceHold / trapData.HoldTime, 1)
				holdGUIFill.Size = UDim2.fromScale(barVal, 1)
			end
		end))
	end))

	OuterTrapJanitor:Add(trap.Unequipped:Connect(function()
		warn("Trap disconnected")
		InnerTrapJanitor:Cleanup()
		ContextActionService:UnbindAction("LMBHeldAction")
		HoldingLMBStart = nil
		holdGUI.Enabled = false
		holdGUIFill.Size = UDim2.fromScale(0, 1)
		HoldingLMB = false
	end))

	OuterTrapJanitor:Add(trap.Destroying:Connect(function()
		InnerTrapJanitor:Cleanup()
		OuterTrapJanitor:Cleanup()
		ContextActionService:UnbindAction("LMBHeldAction")
		holdGUI.Enabled = false
		holdGUIFill.Size = UDim2.fromScale(0, 1)
		HoldingLMBStart = nil
		HoldingLMB = false
	end))
end

return ClientTrapHandler
