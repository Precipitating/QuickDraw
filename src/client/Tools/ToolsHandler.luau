local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local AnimationsHandler = require(script.Parent.Parent.Animations.AnimationsHandler)
local PopupHandler = require(script.Parent.Parent.GUI.PopupHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local CommonToolLogic = require(script.Parent.CommonToolLogic)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ToolsHandler = {}

ToolsHandler.networker = Networker.new("ToolNetwork", ToolsHandler)

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
	PlayerContext.IsBusy = true
	local placeAnim: AnimationTrack = AnimationsHandler.PlayCustomAnimation("PlaceDownTrap")
	local placeMarkerConn = placeAnim:GetMarkerReachedSignal("Placed"):Once(function()
		if humanoid.Health >= 0 then
			local placed = ToolsHandler.networker:fetch("PlaceDownTrap", trap)

			if not placed then
				if trap.Name == "RopeTrap" then
					PopupHandler:NewPopup(2, "Cannot place trap, it needs a ceiling within 50 studs above trap.")
				else
					PopupHandler:NewPopup(2, "Cannot place trap, invalid floor or no floor found")
				end

				SoundManager.PlayKeyed("SFX", "Error")
				return
			end
			SoundManager.PlayKeyed("SFX", placeSoundName)
			thrown = placed
		end
	end)

	--
	placeAnim.Stopped:Once(function()
		PlayerContext.IsBusy = false
		if placeMarkerConn then
			placeMarkerConn:Disconnect()
		end

		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed = HumanConstants.WALKSPEED
		end
	end)

	return thrown
end

function ToolsHandler:ConnectTrap(trap: Tool)
	local trapData = TrapData[trap.Name]
	if not trapData then
		Utility.Warn(`Missing trap data for client to connect`)
		return false
	end

	CommonToolLogic:ConnectConsumableTool(trap, trapData.HoldTime, trapData, function()
		PlaceDownTrap(trap, trapData.PlaceSoundName)
	end)

	return true
end

return ToolsHandler
