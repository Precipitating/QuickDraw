local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MathUtils = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.Utils.MathUtils)
local NPCWeaponsClass = require(ServerScriptService.Server.LightweightNpcs.Code.NPCWeaponsClass)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local ActionResult = require(script.Parent.ActionResult)
local CommonStateLogic = require(script.Parent.CommonStateLogic)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local Provoked = {}

function Provoked:Update(agent: LightweightNpcTypes.npcRecordType, context)
	local dt = context.dt
	local perception = agent.ai.perception
	perception.update()

	local shotPos = agent.data.shotPosition
	local dir = (shotPos - agent.position).Unit
	agent.targetAngle = MathUtils:PlayerVecToAngle(dir)
	agent:Move(Vector3.zero)
	agent.velocity = Vector3.zero

	local seesTarget = CommonStateLogic.CanSeeEnemy(agent, dt)
	if seesTarget then
		agent.ai.currentTarget = seesTarget
		warn("Provoked AI sees enemy")
		return ActionResult.Success
	else
		task.wait(3)
		return ActionResult.Success
	end
end

return Provoked
