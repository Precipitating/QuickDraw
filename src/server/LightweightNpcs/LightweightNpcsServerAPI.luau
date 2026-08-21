local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local defaultAnims = require(game.ServerScriptService.Server.LightweightNpcs.Code.DefaultAnims)
local lightweightNpcsServerModule = require(script.Parent.Code.LightweightNpcsServerModule)

type customNpcsServerAPIType = {
	SpawnNPC: (self: customNpcsServerAPIType, template: Model, position: Vector3, angleRad: number) -> (),
}

function module:CreateConfig()
	return {
		animations = defaultAnims:GetDefaultAnimations(),
		motionSize = Vector3.new(6, 6, 6),
		collisionGroup = "NPC",
		canCollide = true,
		groundTolerance = 0.5,
		maximumStepHeight = 5,
		maximumSlopeHeight = 50,
		replicationHzRate = 10, -- This is complicated. Higher values are more responsive for motion, and cost more bandwidth
		thinkHzRate = 10, --How frequently this NPC runs its simulation
		maxHitPoints = HumanConstants.MAX_HP,
		walkSpeed = HumanConstants.WALKSPEED, --Same as roblox
		walkAccel = 20, --Roblox is really high, like 20. 3-4 is much more natural looking
		turnSpeed = math.rad(270), --In radians per second
		gravity = Vector3.new(0, -game.Workspace.Gravity, 0),
		jumpPower = 60,
	}
end

function module:SpawnNpc(
	template: Model,
	configuration: any,
	npcType: string,
	spawnerType: string,
	defaultStateData: string,
	originCFrame: CFrame
)
	if configuration.thinkHzRate < configuration.replicationHzRate then
		warn("Setting your thinkHzRate lower than your replication rate will cause stuttering")
	end

	local npcRecord = lightweightNpcsServerModule:CreateNpc(
		template,
		configuration,
		npcType,
		spawnerType,
		defaultStateData,
		originCFrame
	)

	return npcRecord
end

function module:GetNpcById(id: number)
	return lightweightNpcsServerModule:GetNPCRecordFromID(id)
end

return module
