local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local AI = require(script.Parent.AI)
local AITypes = require(script.Parent.AITypes)
local UP = vector.create(0, 1, 0)

type Human = ClassTypes.Human

local RangeAI = setmetatable({}, AI)
RangeAI.__index = RangeAI

function RangeAI.new(human: Human)
	local self = setmetatable(AI.new(human), RangeAI)
	self.Type = "Range"
	self.TypeInfo = AITypes[self.Type]

	return self
end

function RangeAI:ToggleRightArmAimer(enable: boolean)
	local rightArmOrientator = self.Owner.RightArmAimer
	assert(rightArmOrientator, "[HumanNPC:ToggleRightArmAimer] RightArmAimer is nil")
	if rightArmOrientator.Enabled == enable then
		return
	end

	if enable then
		rightArmOrientator.Enabled = true
	else
		rightArmOrientator.Enabled = false
	end
end

function RangeAI:AimRightArmTowards(target)
	local rightArm = self.Owner.BodyParts["RightUpperArm"]
	local origin = rightArm.Position

	local targetPos = target:IsA("Model") and target:GetPivot().Position or target.Position

	local lookCF = CFrame.lookAt(origin, targetPos)

	-- smooth time-based noise
	local t = os.clock() * HumanConstants.SWAY_SPEED
	local seed = self.NoiseSeed

	local yawNoise = math.noise(seed, t, 0)
	local pitchNoise = math.noise(seed, 0, t)

	local swayYaw = yawNoise * HumanConstants.SWAY_AMOUNT
	local swayPitch = pitchNoise * HumanConstants.SWAY_AMOUNT

	lookCF *= CFrame.Angles(math.rad(90) + swayPitch, swayYaw, 0)

	self.Owner.RightArmAimer.CFrame = lookCF
end
function RangeAI:StartAttackState(target)
	local attackDist = self.TypeInfo.AttackDistance
	local minAttackDist = self.TypeInfo.MinAttackDistance

	self.CurrentState = "Attack"

	task.spawn(function()
		while task.wait(self.TypeInfo.AttackCooldown) do
			local character = self.Owner.Character

			if not character then
				return
			end
			if not target or not target.Parent then
				return
			end

			local charPos = character:GetPivot().Position
			local targetPos = target:GetPivot().Position
			local distDiff = targetPos - charPos
			local distSquared = distDiff:Dot(distDiff)

			if self.CurrentState ~= "Attack" then
				return
			end

			-- Too far: move toward target (stop at attackDist range)
			local attackDistSquared = ((attackDist + self.PathfindTolerance) ^ 2)
			local minAttackDistSquared = minAttackDist ^ 2

			if distSquared > attackDistSquared then
				if not self.CurrentlyMoving then
					self:ToggleRightArmAimer(false)
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
					self:ToggleRightArmAimer(false)
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

			-- In valid range: stop, aim, and attack
			self:ToggleRightArmAimer(true)
			self:AimRightArmTowards(target)
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

	-- Cache these once on equip in production (see note below)
	local handle = tool:WaitForChild("Handle", 10)
	local shootPoint = tool:WaitForChild("ShootPoint", 10)
	local rightArm = human.BodyParts.RightUpperArm

	if not (handle and shootPoint and rightArm) then
		return
	end

	-- Fire weapon logic first
	currentGun:ShootGun()

	--recoil impulse
	local handleImpulse = handle.AssemblyMass * UP * 100
	handle:ApplyImpulseAtPosition(handleImpulse, shootPoint.WorldPosition)
end

return RangeAI
