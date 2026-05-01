local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Stack = require(ReplicatedStorage.Shared.Classes.Stack)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Fallback = require(ServerScriptService.Server.Classes.AIBehaviour.States.Fallback)
local Patrol = require(ServerScriptService.Server.Classes.AIBehaviour.States.Patrol)
local RangeAttack = require(ServerScriptService.Server.Classes.AIBehaviour.States.RangeAttack)
local Stalk = require(ServerScriptService.Server.Classes.AIBehaviour.States.Stalk)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)

local AI = require(script.Parent.AI)

local UP = vector.create(0, 1, 0)

type Human = ClassTypes.Human
type Stack = Stack.Stack<Vector3>
local RangeAI = setmetatable({}, AI)
RangeAI.__index = RangeAI

function RangeAI.new(human: Human, classType: string, optionalData: any?)
	local classData = NPCTypes[classType]
	assert(classData, "NPC Class Type doesn't exist")
	local self = setmetatable(AI.new(human, classType), RangeAI)
	self.Type = classType
	self.MaxAttackDistance = classData.MaxAttackDistance
	self.PatrolStayTime = classData.PatrolStayTime
	self.MinAttackDistance = classData.MinAttackDistance
	self.EyeRange = classData.EyeRange
	self.WeaponName = classData.WeaponName
	self.ThrowableName = classData.ThrowableName
	self.AttackState = (classData and classData.AttackStateName)
			and {
				Name = classData.AttackStateName,
				Data = (classData and classData.AttackStateData) or (optionalData and optionalData.AttackStateData),
			}
		or nil
	self.DefaultState = (classData and classData.DefaultStateName)
			and {
				Name = classData.DefaultStateName,
				Data = (classData and classData.DefaultStateData) or (optionalData and optionalData.DefaultStateData),
			}
		or nil
	self.AttackCooldown = classData.AttackCooldown
	self:RangeInitialize()

	return self
end

function RangeAI:RangeInitialize()
	self.StateMachine:AddState("Patrol", Patrol.new(self.StateMachine, self))
	self.StateMachine:AddState("RangeAttack", RangeAttack.new(self.StateMachine, self))
	self.StateMachine:AddState("Fallback", Fallback.new(self.StateMachine, self))
	self.StateMachine:AddState("Stalk", Stalk.new(self.StateMachine, self))

	task.defer(function()
		self.StateMachine:Transition(self.DefaultState.Name, self.DefaultState.Data)
	end)
end

-- Helper: raycast downward to snap candidate to ground level
function RangeAI:GetGroundY(pos: Vector3): number?
	local origin = Vector3.new(pos.X, pos.Y + 50, pos.Z)
	local direction = Vector3.new(0, -200, 0)
	local result = workspace:Raycast(origin, direction, self.RaycastParams)
	if result then
		return result.Position.Y
	end
	return nil
end

-- Find a valid position around target (circular around)
-- It only returns positions that the the AI will have a line of sight to
function RangeAI:FindAnglePosition(
	originPos: Vector3,
	target: Model | BasePart,
	customPosition: Vector3?,
	radius: number,
	recursing: boolean
): Vector3?
	local targetPos: Vector3

	if customPosition then
		targetPos = customPosition
	else
		if typeof(target) == "Instance" then
			if target:IsA("Model") then
				targetPos = target:GetPivot().Position
			elseif target:IsA("BasePart") then
				targetPos = (target :: BasePart).Position
			else
				return nil
			end
		end
	end

	local baseDir = (originPos - targetPos)
	-- Flatten to XZ for rotation, but preserve a reference Y
	local baseDirFlat = Vector3.new(baseDir.X, 0, baseDir.Z)
	if baseDirFlat.Magnitude < 0.001 then
		baseDirFlat = Vector3.new(1, 0, 0) -- fallback if directly above/below
	end
	baseDirFlat = baseDirFlat.Unit

	local bestCandidate: Vector3? = nil
	local bestScore = math.huge

	-- Two-pass: coarse then fine around best coarse hit
	local function evaluateCandidates(angleList: { number })
		for _, angle in ipairs(angleList) do
			local radians = math.rad(angle)
			local cos, sin = math.cos(radians), math.sin(radians)
			local rotated =
				Vector3.new(baseDirFlat.X * cos - baseDirFlat.Z * sin, 0, baseDirFlat.X * sin + baseDirFlat.Z * cos)

			-- Raycast downward to find ground Y so the candidate sits on terrain
			local candidateXZ = targetPos + rotated * radius
			local groundY = self:GetGroundY(candidateXZ) or targetPos.Y
			local candidate = Vector3.new(candidateXZ.X, groundY, candidateXZ.Z)

			if self:IsTargetInView(candidate, target, false) then
				-- Score: weighted sum of distance to origin + distance to target (prefer mid-range)
				local distToOrigin = (originPos - candidate).Magnitude
				local distToTarget = (targetPos - candidate).Magnitude
				-- Penalise straying far from the requested radius
				local radiusDrift = math.abs(distToTarget - radius)
				local score = distToOrigin + radiusDrift * 0.5

				if score < bestScore then
					bestScore = score
					bestCandidate = candidate
				end
			end
		end
	end

	-- Pass 1: coarse sweep every 15°
	local coarseAngles = {}
	for angle = 0, 359, 15 do
		table.insert(coarseAngles, angle)
	end
	evaluateCandidates(coarseAngles)

	-- Pass 2: fine sweep 15° around best coarse result in 3° steps
	if bestCandidate then
		local bestAngle = math.deg(math.atan2(bestCandidate.Z - targetPos.Z, bestCandidate.X - targetPos.X))
		local fineAngles = {}
		for offset = -15, 15, 3 do
			table.insert(fineAngles, bestAngle + offset)
		end
		evaluateCandidates(fineAngles)
	end

	if bestCandidate then
		return bestCandidate
	end

	-- Radius expansion with early-out
	if recursing then
		return nil
	end

	for _ = 1, 6 do
		radius *= 1.25
		local candidate = self:FindAnglePosition(originPos, target, customPosition, radius, true)
		if candidate then
			return candidate
		end
	end

	return nil
end

-- Ensure the AI is within the shooting position
function RangeAI:CorrectRangePosition(targetPos: Vector3): string | boolean
	local currentPos = self.Owner.Character:GetPivot().Position
	local distance = (targetPos - currentPos).Magnitude

	-- Must be 5 studs PAST max before seeking, add a buffer to account for pathfinding inaccuracies
	if distance >= self.MaxAttackDistance + 5 then
		return "Seek"
	end
	-- Must be 5 studs PAST min before falling back
	if distance <= self.MinAttackDistance - 5 and not self.Owner.Legless then
		return "Fallback"
	end
	if not self.Owner.Legless then
		self:ChangeWalkSpeed(HumanConstants.WALKSPEED)
	end
	return true
end

function RangeAI:Attack()
	local human = self.Owner
	local currentGun = human and human.CurrentGun
	if not currentGun then
		return
	end

	local tool = currentGun.Tool
	if not tool then
		return
	end

	local handle = currentGun.Handle
	local shootPoint = currentGun.ShootPoint
	local rightArm = human.BodyParts.RightUpperArm

	if not (handle and shootPoint and rightArm) then
		return
	end

	-- Reload if 0 ammo
	if currentGun.CurrentAmmo <= 0 then
		if self.Owner.CurrentGun.Reloading then
			return
		end
		task.spawn(function()
			currentGun:Reload()
		end)
	else
		-- Keep reloading if we still have ammo, unless interrupted by getting hit
		-- OR player goes too close to enemy
		if self.Owner.CurrentGun.Reloading then
			return
		end
		currentGun:ShootGun()
	end

	--recoil impulse
	local handleImpulse = handle.AssemblyMass * UP * 100
	handle:ApplyImpulseAtPosition(handleImpulse, shootPoint.WorldPosition)
end

return RangeAI
