local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local AI = require(script.Parent.AI)
local PatrolData = require(script.Parent.PatrolData)
local UP = vector.create(0, 1, 0)

type Human = ClassTypes.Human

local RangeAI = setmetatable({}, AI)
RangeAI.__index = RangeAI

RangeAI.StatesLogic = table.clone(AI.StatesLogic)

RangeAI.StatesLogic.Attack = {
	Update = function(self, target)
		self:StartAttackState(target)
	end,
}

function RangeAI.new(human: Human)
	local self = setmetatable(AI.new(human), RangeAI)
	self.Type = "Range"
	self.LineOfSight = 100
	self.MinAttackDistance = 15
	self.AttackCooldown = 1
	return self
end

function RangeAI:FindAnglePosition(originPos: Vector3, target: Model | BasePart, radius: number)
	local targetPos = if target:IsA("Model") then target:GetPivot().Position else target.Position
	local baseDir = (originPos - targetPos).Unit

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
		-- Debris:AddItem(prt, 1)

		if AI.IsTargetInView(self, candidate, target) then
			return candidate
		end
	end

	return nil
end
function RangeAI:StartAttackState(target: BasePart)
	self.CurrentlyMoving = false
	local attackDist = self.LineOfSight
	local currentState = self.CurrentState
	self.CurrentState = "Attack"

	task.spawn(function()
		while task.wait(self.AttackCooldown) do
			local character = self.Owner.Character
			if not character then
				return
			end

			if not target or not target.Parent or currentState ~= "Attack" then
				AI.ChangeState(self, "Seek")

				return
			end

			local charPos = character:GetPivot().Position
			local targetPos = target:GetPivot().Position
			local distDiff = targetPos - charPos
			local distSquared = distDiff:Dot(distDiff)

			-- Too far: move toward target (stop at attackDist range)
			local attackDistSquared = ((attackDist + self.PathfindTolerance) ^ 2)
			local minAttackDistSquared = self.MinAttackDistance ^ 2

			if distSquared > attackDistSquared then
				if math.abs(distSquared - attackDistSquared) > self.LineOfSight then
					AI.ChangeState(self, "Seek")
					return
				end

				if not self.CurrentlyMoving then
					self.Owner:ToggleRightArmAimer(false)
					-- Move TOWARD the target, stopping at attackDist away
					local dir = distDiff.Unit
					local moveGoal = targetPos - (dir * attackDist)
					task.spawn(function()
						AI.PathFindTo(self, moveGoal)
					end)
				end
				continue
			elseif distSquared < minAttackDistSquared then
				if not self.CurrentlyMoving then
					self.Owner:ToggleRightArmAimer(false)
					-- Move AWAY from the target along X/Z, keeping Y neutral
					-- Direction from target to self (away from target)
					local awayDir = (charPos - targetPos)
					-- Flatten Y so the AI doesn't try to fly up/down
					awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
					-- Fallback if directly on top of target
					if awayDir.Magnitude < 0.01 then
						awayDir = Vector3.new(1, 0, 0)
					end
					awayDir = awayDir.Unit
					-- Move to a point that is attackDist away from the target (in the away direction)
					local moveGoal = targetPos + (awayDir * attackDist)
					task.spawn(function()
						AI.PathFindTo(self, moveGoal)
					end)
				end
				continue
			end

			-- Check if the NPC can see the player

			if AI.IsTargetInView(self, self.Owner.BodyParts["Head"].Position, target) then
				-- In valid range: stop, aim, and attack
				if self.CurrentlyMoving then
					continue
				end
				self.Owner:ToggleRightArmAimer(true)
				self.Owner:AimRightArmTowards(target)
				self:Attack()
				self.LastSeenTargetPosition = targetPos
			else
				self.Owner:ToggleRightArmAimer(false)
				task.spawn(function()
					local validPos = self:FindAnglePosition(charPos, target, attackDist)
					if validPos then
						AI.PathFindTo(self, validPos)
					else
						warn("AI CANT SEE TARGET")
						AI.ChangeState(self, "Seek")
						return
					end
				end)
			end
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
