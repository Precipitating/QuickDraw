local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
return {
	TryPathfind = function(agent: LightweightNpcTypes.npcRecordType, destination)
		if agent.busy or not destination then
			return false
		end

		agent.busy = true
		local ok, calcPath = pcall(function()
			return agent.ai.pathfinder:findPath(agent.position, destination)
		end)
		agent.busy = false

		if not ok then
			Utility.Warn(`[TryPathfind] findPath errored: {calcPath}`)
			agent.ai.currentNavigationData = nil
			agent:Move(Vector3.zero)
			return false
		end

		-- local col = Color3.fromRGB(
		-- 	RandomModule.GetRandomIntBetween(0, 255),
		-- 	RandomModule.GetRandomIntBetween(0, 255),
		-- 	RandomModule.GetRandomIntBetween(0, 255)
		-- )
		if calcPath.success then
			-- for _, path in calcPath.waypoints do
			-- 	local l = Instance.new("Part", workspace)
			-- 	l.Color = col
			-- 	l.Anchored = true
			-- 	l.CanCollide = false
			-- 	l.Position = path.Position
			-- end
			agent.ai.currentNavigationData = calcPath
			agent.ai.currentMoveIdx = 2
			return true
		end

		agent.ai.currentNavigationData = nil
		agent:Move(Vector3.zero)
		return false
	end,

	MoveToward = function(agent: LightweightNpcTypes.npcRecordType, targetPos)
		local flatTarget = Vector3.new(targetPos.X, agent.position.Y, targetPos.Z)
		local dir = flatTarget - agent.position
		agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	end,
	MoveTowardFlattened = function(agent: LightweightNpcTypes.npcRecordType, targetPos)
		local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
		local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
		local dir = flatTarget - flatAgentPos
		agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	end,

	CanSeeEnemy = function(npcRecord: LightweightNpcTypes.npcRecordType, dt: number)
		local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
		local perception = npcRecord.ai.perception
		local perceiverPos = npcRecord.position
		local npcTypeData = NPCTypes[npcRecord.npcType]
		local range = npcTypeData and npcTypeData.EyeRange

		if not perception or not enemyInstanceTags or not perceiverPos or not range then
			return nil
		end

		local rangeSq = range * range
		local perceiverHrpPos = npcRecord.hrp.Position
		local perceiverLookVector = npcRecord.hrp.CFrame.LookVector

		local candidates = Utility.GetTagInstancesInWorkspace("NPC")
		for _, playerCharacter in Utility.GetTagInstancesInWorkspace("Player") do
			table.insert(candidates, playerCharacter)
		end

		for _, model: Model in candidates do
			if model == npcRecord.serverRig or model:HasTag("Dead") then
				continue
			end

			local isEnemy = false
			for _, tag in enemyInstanceTags do
				if model:HasTag(tag) then
					isEnemy = true
					break
				end
			end
			if not isEnemy then
				continue
			end

			local modelPos = model:GetPivot().Position
			if (modelPos - perceiverPos).Magnitude > rangeSq ^ 0.5 then
				continue
			end

			local targetId = model:GetAttribute("npcId") or model.Name
			local detected = perception:processVisualDetection(targetId, perceiverHrpPos, perceiverLookVector, modelPos)

			if detected and perception:getAwarenessState(targetId) == "combat" then
				return model
			end
		end

		return nil
	end,
}
