local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local Reload = {}

function Reload:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local gunData = agent.currentEquippedData
	if not gunData then
		Utility.Warn(`Cannot reload, missing gun data`)
		return ActionResult.Failed
	end

	local maxAmmo = gunData.MaxAmmo
	if agent.currentWeaponAmmo >= maxAmmo then
		Utility.Warn(`Can shoot now`)
		return ActionResult.Success
	end

	local perBulletReload = gunData.ReloadTimePerBullet
	local reloadSound = gunData.ReloadSoundName
	local reloadSoundStart = gunData.ReloadSoundStartName
	local magazineReload = gunData.ReloadTime

	if not agent.data.lastReloaded then
		agent.data.lastReloaded = os.clock()
	end

	if (os.clock() - agent.data.lastReloaded) >= (perBulletReload or magazineReload) then
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
