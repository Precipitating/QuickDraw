local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local LightweightNpcTypes = require(game.ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Precomputed once at module load instead of rebuilt on every call
local COARSE_STEP = 15
local COARSE_DIRS = table.create(24)
do
	for angle = 0, 359, COARSE_STEP do
		local radians = math.rad(angle)
		table.insert(COARSE_DIRS, { cos = math.cos(radians), sin = math.sin(radians), angle = angle })
	end
end

local function GetGroundY(pos: Vector3): number?
	local origin = vector.create(pos.X, pos.Y + 50, pos.Z)
	local direction = vector.create(0, -200, 0)
	local result = workspace:Raycast(origin, direction, raycastParams)
	if result then
		return result.Position.Y
	end
	return nil
end

local function FindAnglePosition(
	agent: LightweightNpcTypes.npcRecordType,
	originPos: Vector3,
	targetPos: Vector3,
	radius: number,
	maxExpansions: number?
): Vector3?
	local baseDir = originPos - targetPos
	local baseDirFlat = vector.create(baseDir.X, 0, baseDir.Z)
	if baseDirFlat.Magnitude < 0.001 then
		baseDirFlat = vector.create(1, 0, 0)
	end
	baseDirFlat = baseDirFlat.Unit

	local perception = agent.ai.perception
	local lookVector = agent.hrp.CFrame.LookVector

	-- Ground raycasts are the expensive part of this loop; the fine
	-- pass frequently re-samples XZ points close to ones the coarse
	-- pass already hit, so cache within this call.
	local groundCache: { [number]: number } = {}
	local function cachedGroundY(x: number, z: number): number
		local key = math.round(x * 2) * 1000000 + math.round(z * 2)
		local cached = groundCache[key]
		if cached then
			return cached
		end
		local y = GetGroundY(Vector3.new(x, targetPos.Y, z)) or targetPos.Y
		groundCache[key] = y
		return y
	end

	local bestCandidate: Vector3? = nil
	local bestScore = math.huge
	local bestAngle = 0

	local function evaluate(cos: number, sin: number, angle: number)
		local dirX = baseDirFlat.X * cos - baseDirFlat.Z * sin
		local dirZ = baseDirFlat.X * sin + baseDirFlat.Z * cos

		local candX = targetPos.X + dirX * radius
		local candZ = targetPos.Z + dirZ * radius
		local groundY = cachedGroundY(candX, candZ)
		local candidate = vector.create(candX, groundY, candZ)

		if not perception:canSee(originPos, lookVector, candidate) then
			return
		end

		local distToOrigin = (originPos - candidate).Magnitude
		local distToTarget = (targetPos - candidate).Magnitude
		local radiusDrift = math.abs(distToTarget - radius)
		local score = distToOrigin + radiusDrift * 0.5

		if score < bestScore then
			bestScore = score
			bestCandidate = candidate
			bestAngle = angle
		end
	end

	local function sweep()
		-- Pass 1: coarse sweep, precomputed table (no per-call trig)
		for _, dir in COARSE_DIRS do
			evaluate(dir.cos, dir.sin, dir.angle)
		end

		-- Pass 2: fine sweep ±15° around best coarse hit, 3° steps
		if bestCandidate then
			local centerAngle = bestAngle
			for offset = -15, 15, 3 do
				if offset ~= 0 then -- 0° already covered by coarse pass
					local angle = centerAngle + offset
					local radians = math.rad(angle)
					evaluate(math.cos(radians), math.sin(radians), angle)
				end
			end
		end
	end

	sweep()
	if bestCandidate then
		return bestCandidate
	end

	-- Radius expansion — iterative, no recursion
	for _ = 1, maxExpansions or 6 do
		radius *= 1.25
		sweep()
		if bestCandidate then
			return bestCandidate
		end
	end

	return nil
end

return {

	FindAnglePosition = FindAnglePosition,
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
