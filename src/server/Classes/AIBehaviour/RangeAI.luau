local Debris = game:GetService("Debris")
local DeviceIdService = game:GetService("DeviceIdService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local AI = require(script.Parent.AI)
local AISignals = require(script.Parent.AISignals)
local PatrolData = require(script.Parent.PatrolData)
local UP = vector.create(0, 1, 0)

type Human = ClassTypes.Human

local RangeAI = setmetatable({}, AI)
RangeAI.__index = RangeAI

RangeAI.StatesLogic = table.clone(AI.StatesLogic)

RangeAI.StatesLogic.Attack = {
	Enter = function(self, target)
		self:StateChangeReset()
		self.CurrentState = "Attack"
		self.StatesLogic["Attack"].Update(self, target)
	end,
	Update = function(self, target)
		self:StartAttackState(target)
	end,
	Exit = function(self) end,
}

function RangeAI.new(human: Human)
	local self = setmetatable(AI.new(human), RangeAI)
	self.Type = "Range"
	self.MaxAttackDistance = 100
	self.MinAttackDistance = 20
	self.AttackCooldown = 1
	return self
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

		-- local prt = Instance.new("Part")
		-- prt.Anchored = true
		-- prt.Parent = workspace
		-- prt.CanCollide = false
		-- prt.CanQuery = false
		-- prt.Size = Vector3.new(1, 1, 1)
		-- prt.Position = candidate
		-- prt.Color = Color3.fromRGB(255, 1, 1)
		-- prt.Transparency = 0.8
		-- Debris:AddItem(prt, 1)

		if AI.IsTargetInView(self, candidate, target, false) then
			--prt.Color = Color3.fromRGB(1, 255, 1)
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
function RangeAI:CorrectRangePosition(target, targetPos)
	local currentPos = self.Owner.Character:GetPivot().Position
	local halfAttackDist = self.MaxAttackDistance * 0.5
	local distance = (targetPos - currentPos).Magnitude

	-- If target too far, change to seek state
	if distance >= self.MaxAttackDistance then
		self.LastSeenTargetPosition = targetPos
		AI.ChangeState(self, "Seek")
		return false
	end

	-- Target too close to NPC, back off.
	if distance <= self.MinAttackDistance then
		if not self.CurrentlyMoving then
			-- find a suitable position around player to go to
			local safePos = self:FindAnglePosition(currentPos, target, halfAttackDist, false)
			if safePos then
				AI.PathFindTo(self, safePos)
				if not self.Owner.Legless then
					self.Owner.Humanoid.WalkSpeed = HumanConstants.SPRINT_SPEED
				end

				AISignals.PathfindComplete:Wait()
			end
		else
			AISignals.PathfindComplete:Wait()
		end
	end

	if not self.Owner.Legless then
		self.Owner.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
	end
	return true
end

function RangeAI:StartAttackState(target: BasePart | Model)
	task.spawn(function()
		while task.wait(self.AttackCooldown) do
			if self.CurrentState ~= "Attack" then
				return
			end
			if not target or not target.Parent then
				AI.ChangeState(self, "Seek")
				return
			end
			local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
			local NPCAimArm = self.Owner.BodyParts["RightUpperArm"]

			-- 1. Check if in shooting range, true if still attack state afterwards
			local inRange = self:CorrectRangePosition(target, targetPos)
			if not inRange then
				return
			end

			-- 2. Aim at target
			self.Owner:ToggleRightArmAimer(true)
			self.Owner:AimRightArmTowards(target)
			task.wait(0.5)
			local isInLineOfSight = AI.IsTargetInView(self, NPCAimArm.Position, target, true)

			if not isInLineOfSight then
				AI.ChangeState(self, "Seek")
				return
			end

			-- 3. Aiming at target, shoot
			self.LastSeenTargetPosition = targetPos
			self:Attack()
		end
	end)
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

	if currentGun.CurrentAmmo <= 0 then
		currentGun:Reload()
	else
		if self.Reloading then
			return
		end
		currentGun:ShootGun()
	end

	--recoil impulse
	local handleImpulse = handle.AssemblyMass * UP * 100
	handle:ApplyImpulseAtPosition(handleImpulse, shootPoint.WorldPosition)
end

return RangeAI
