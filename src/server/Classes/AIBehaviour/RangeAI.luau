local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Patrol = require(ServerScriptService.Server.Classes.AIBehaviour.States.Patrol)
local RangeAttack = require(ServerScriptService.Server.Classes.AIBehaviour.States.RangeAttack)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)

local AI = require(script.Parent.AI)
local AISignals = require(script.Parent.AISignals)

local UP = vector.create(0, 1, 0)

type Human = ClassTypes.Human

local RangeAI = setmetatable({}, AI)
RangeAI.__index = RangeAI

function RangeAI.new(human: Human)
	local self = setmetatable(AI.new(human), RangeAI)
	self.Type = "Range"
	self.MaxAttackDistance = 100
	self.PatrolStayTime = 5
	self.MinAttackDistance = 20
	self.EyeRange = 250
	self.DefaultPatrolKey = "1"
	self.AttackStateName = "RangeAttack"
	self.AttackCooldown = 1
	self:RangeInitialize()
	return self
end

function RangeAI:RangeInitialize()
	self.StateMachine:AddState("Patrol", Patrol.new(self.StateMachine, self))
	self.StateMachine:AddState("RangeAttack", RangeAttack.new(self.StateMachine, self))

	self.StateMachine:Transition("Patrol", self.DefaultPatrolKey)
end
function RangeAI:FindAnglePosition(originPos: Vector3, target: Model | BasePart, radius: number, recursing: boolean)
	local targetPos = if (typeof(target) == "Vector3" or not target:IsA("Model"))
		then target
		else target:GetPivot().Position
	local baseDir = (originPos - targetPos).Unit
	local candidates = {}
	for angle = 0, 360, 30 do
		local radians = math.rad(angle)
		local rotated = Vector3.new(
			baseDir.X * math.cos(radians) - baseDir.Z * math.sin(radians),
			0,
			baseDir.X * math.sin(radians) + baseDir.Z * math.cos(radians)
		)
		local candidate = targetPos + rotated * radius

		local candidateDir = (candidate - targetPos).Unit
		if candidateDir:Dot(baseDir) < 0 then
			continue
		end

		if AI.IsTargetInView(self, candidate, target, false) then
			table.insert(candidates, candidate)
		end
	end
	if #candidates > 0 then
		return candidates[RandomModule.GetRandomIntBetween(1, #candidates)]
	end
	if recursing then
		return nil
	end
	for _ = 1, 6 do
		radius *= 1.1
		local hasCandidate = self:FindAnglePosition(originPos, target, radius, true)
		if hasCandidate then
			return hasCandidate
		end
	end
	return nil
end

-- Ensure the AI is within the shooting position
function RangeAI:CorrectRangePosition(target, targetPos: Vector3, targetDir: Vector3?)
	local currentPos = self.Owner.Character:GetPivot().Position
	local halfAttackDist = self.MaxAttackDistance * 0.5
	local distance = (targetPos - currentPos).Magnitude

	-- If target too far, change to seek state
	if distance >= self.MaxAttackDistance then
		self.StateMachine:Transition("Seek", { ShotPosition = targetPos, TargetDirection = targetDir })
		return false
	end

	-- Target too close to NPC, back off.
	if distance <= self.MinAttackDistance and not self.Owner.Legless then
		ServerSoundHandler:Play3DNPCVoiceline(
			nil,
			`RangedAIBackOff{RandomModule.GetRandomIntBetween(1, 3)}`,
			self.Owner.VoicelineSound,
			{ MaxDistance = 200 }
		)
		self.Owner.CurrentGun.Reloading = false
		-- find a suitable position around player to go to
		local safePos = self:FindAnglePosition(currentPos, target, halfAttackDist, false)
		if not safePos then
			return false
		end

		AI.PathFindTo(self, safePos)

		self.Owner.Humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED

		AISignals.PathfindComplete:Wait()
	end

	if not self.Owner.Legless then
		self.Owner.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
	end
	return true
end

function RangeAI:Attack()
	local human = self.Owner
	local currentGun = human.CurrentGun
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
