local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local Reload = {}
function Reload:ExitReloadState(agent: LightweightNpcTypes.npcRecordType)
	Utility.Warn(`Can shoot now`)
	agent.data.lastReloaded = nil
end
function Reload:Update(agent: LightweightNpcTypes.npcRecordType, context)
	if agent.data.forceExitState then
		self:ExitReloadState(agent)
		if agent.currentWeaponAmmo > 0 then
			agent.ai.worldState:set("canShoot", true)
		else
			agent.ai.worldState:set("canShoot", false)
		end
		return ActionResult.Failed
	end
	local gunData = agent.currentEquippedData
	if not gunData then
		Utility.Warn(`Cannot reload, missing gun data`)
		return ActionResult.Failed
	end

	local maxAmmo = gunData.MaxAmmo
	if agent.currentWeaponAmmo >= maxAmmo then
		self:ExitReloadState(agent)
		return ActionResult.Success
	end

	local perBulletReload = gunData.ReloadTimePerBullet
	local reloadSound = gunData.ReloadSoundName
	local reloadSoundStart = gunData.ReloadSoundStartName
	local magazineReload = gunData.ReloadTime

	if agent.currentEquipped and not agent.legless then
		agent:PlayAnimation("toolhold", false, 2, 1)
		agent.onPoseChange:Fire("toolhold", 2)
	end

	if not agent.data.lastReloaded then
		agent.data.lastReloaded = os.clock()
	end

	local lastReloaded = os.clock() - agent.data.lastReloaded
	if lastReloaded >= (perBulletReload or magazineReload) then
		Utility.Warn(`Loading next bullet...`)
		if reloadSoundStart then
			ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSoundStart, agent.position)
		end

		if reloadSound then
			ServerSoundHandler:Play3DOneShotToOthers(nil, reloadSound, agent.position)
		end

		NPCWeaponsClass:UpdateAmmo(agent, 1)
		Utility.Warn(`{agent.currentWeaponAmmo}`)

		agent.data.lastReloaded = os.clock()
	end

	return ActionResult.Running
end

return Reload
