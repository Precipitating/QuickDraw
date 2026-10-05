local ServerScriptService = game:GetService("ServerScriptService")
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local Utility = require(game:GetService("ReplicatedStorage").Shared.Utility.Utility)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local TOOLHOLD_REFRESH = 1

local Reload = {}

function Reload:ExitReloadState(agent: LightweightNpcTypes.npcRecordType)
	agent.data.lastReloaded = nil
	agent.data.nextToolHoldRefresh = nil
end

function Reload:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local data = agent.data

	if data.forceExitState then
		self:ExitReloadState(agent)
		agent.ai.worldState:set("canShoot", agent.currentWeaponAmmo > 0)
		return ActionResult.Failed
	end

	local gunData = agent.currentEquippedData
	if not gunData then
		Utility.Warn(`[Reload] Cannot reload, missing gun data`)
		return ActionResult.Failed
	end

	if agent.currentWeaponAmmo >= gunData.MaxAmmo then
		self:ExitReloadState(agent)
		return ActionResult.Success
	end

	local perBulletTime = gunData.ReloadTimePerBullet
	local magazineTime = gunData.ReloadTime
	local interval = perBulletTime or magazineTime
	if not interval then
		Utility.Warn(`[Reload] Gun has no reload time configured`)
		return ActionResult.Failed
	end

	local now = os.clock()

	-- First tick: start the timer and stand still
	if not data.lastReloaded then
		data.lastReloaded = now
		agent:Move(Vector3.zero)
		agent.velocity = Vector3.zero
		CommonStateLogic.PlayLocomotion(agent, "idle")
	end

	if agent.currentEquipped and not agent.legless and now >= (data.nextToolHoldRefresh or 0) then
		data.nextToolHoldRefresh = now + TOOLHOLD_REFRESH
		agent:PlayAnimation("toolhold", false, 2, 1)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	if now - data.lastReloaded >= interval then
		if gunData.ReloadSoundStartName then
			ServerSoundHandler:Play3DOneShotToOthers(nil, gunData.ReloadSoundStartName, agent.position)
		end
		if gunData.ReloadSoundName then
			ServerSoundHandler:Play3DOneShotToOthers(nil, gunData.ReloadSoundName, agent.position)
		end

		NPCWeaponsClass:UpdateAmmo(agent, if magazineTime then gunData.MaxAmmo else 1)
		data.lastReloaded = now
	end

	return ActionResult.Running
end

return Reload
