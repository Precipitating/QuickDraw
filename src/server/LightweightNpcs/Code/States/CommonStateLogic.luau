local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
return {
	TryPathfind = function(agent, destination)
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

	MoveToward = function(agent, targetPos)
		local flatTarget = Vector3.new(targetPos.X, agent.position.Y, targetPos.Z)
		local dir = flatTarget - agent.position
		agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	end,
	MoveTowardFlattened = function(agent, targetPos)
		local flatAgentPos = Vector3.new(agent.position.X, 0, agent.position.Z)
		local flatTarget = Vector3.new(targetPos.X, 0, targetPos.Z)
		local dir = flatTarget - flatAgentPos
		agent:Move(dir.Magnitude > 0.001 and dir.Unit or Vector3.zero)
	end,

	CanSeeEnemy = function(npcRecord: LightweightNpcTypes.npcRecordType, dt: number)
		local enemyInstanceTags = npcRecord.enemies and npcRecord.enemies.EnemyList
		local perception = npcRecord.ai.perception
		local perceiverPos = npcRecord.position
		local range = NPCTypes[npcRecord.npcType] and NPCTypes[npcRecord.npcType].EyeRange
		if not perception or not enemyInstanceTags or not perceiverPos or not range then
			return nil
		end

		local activeHumans = Utility.GetTagInstancesInWorkspace("NPC")

		for _, playerCharacter in Utility.GetTagInstancesInWorkspace("Player") do
			table.insert(activeHumans, playerCharacter)
		end

		-- prune out of distance characters
		for idx, humanModel: Model in activeHumans do
			local dist = (humanModel:GetPivot().Position - npcRecord.position).Magnitude

			if (dist > range) or humanModel == npcRecord.serverRig then
				-- swap to back and pop
				activeHumans[idx], activeHumans[#activeHumans] = activeHumans[#activeHumans], activeHumans[idx]
				table.remove(activeHumans)
			end
		end

		for _, model: Model in activeHumans do
			local isEnemy = false
			for _, tag in enemyInstanceTags do
				if model:HasTag(tag) then
					isEnemy = true
					break
				end
			end

			if isEnemy and not model:HasTag("Dead") then
				local targetId = model:GetAttribute("npcId") or model.Name
				local detected, gain = perception:processVisualDetection(
					targetId,
					npcRecord.hrp.Position,
					npcRecord.hrp.CFrame.LookVector,
					model:GetPivot().Position
				)
				local awarenessState = perception:getAwarenessState(targetId)
				if detected and awarenessState == "combat" then
					return model
				end
			end
		end

		return nil
	end,
}
