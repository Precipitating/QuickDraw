local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local LightweightNpcsClientModule =
	require(StarterPlayer.StarterPlayerScripts.Client.LightweightNpcsClient.Code.LightweightNpcsClientModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local CoreGUIHandler = require(script.Parent.Utility.CoreGUIHandler)

local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ColorCorrection: ColorCorrectionEffect = Lighting:WaitForChild("ColorCorrection")
local HumanNetwork = {}
HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork)

function HumanNetwork:RagdollClient(ragdollTime: number)
	if not PlayerContext.Humanoid then
		Utility.Warn("Can't ragdoll on client, humanoid missing")
		return
	end
	local Inputs = require(script.Parent.ClientInputs.Inputs)

	PlayerContext.Humanoid:UnequipTools()
	PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	Inputs.networker:fire("ToggleSprint", false)
	Inputs:StopBarge(nil)
	task.delay(ragdollTime, function()
		if PlayerContext.Humanoid then
			PlayerContext.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function HumanNetwork:ApplyImpulse(target, force: Vector3, position: Vector3?, type: string?)
	if not target then
		return
	end

	-- Apply NPC gun recoil visual
	if type then
		if type == "NPCRecoil" then
			local npcModel = target
			if not npcModel then
				return
			end
			local npcRecord = LightweightNpcsClientModule.npcRecords[target:GetAttribute("npcId")]
			if not npcRecord then
				return
			end

			-- Apply visual impulse
			local gunName: string? = npcModel:FindFirstChildOfClass("Tool")
				and npcModel:FindFirstChildOfClass("Tool").Name
			local gunData = GunData[gunName]
			if not gunData then
				return
			end
			npcRecord.recoilSpring:impulse(gunData.GunRecoil)

			--ClientGunHandler:ApplyNPCRecoil(npcModel:FindFirstChild("RightUpperArm")
		end
		return
	end

	task.defer(function()
		if position then
			target:ApplyImpulseAtPosition(force, position)
		else
			target:ApplyImpulse(force)
		end
	end)
end

function HumanNetwork:FinishedLoadingGame()
	self.networker:fire("FinishedLoadingGame")
end
function HumanNetwork:ToggleBackpackVisibility(active: boolean, locked: boolean?)
	CoreGUIHandler.ToggleBackpackVisibility(active, locked)
end

function HumanNetwork:AdjustGrayscale(saturationTarget: number)
	ColorCorrection.Saturation = saturationTarget
end

return HumanNetwork
