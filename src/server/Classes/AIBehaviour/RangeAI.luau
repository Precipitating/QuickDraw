local Debris = game:GetService("Debris")
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
	self.LineOfSight = 100

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

function RangeAI:IsTargetInView(originPos: Vector3, target: BasePart | Model | Vector3)
	local targetPos = nil

	if typeof(target) == "Vector3" then
		targetPos = target
	elseif target:IsA("Model") then
		targetPos = target:GetPivot().Position
	elseif target:IsA("BasePart") then
		targetPos = target.Position
	end

	local dir = (targetPos - originPos).Unit
	local raycastParam = RaycastParams.new()
	raycastParam.FilterDescendantsInstances = { self.Owner.Character }
	local lineOfSight = workspace:Raycast(originPos, dir * self.LineOfSight, raycastParam)

	-- local part = Instance.new("Part")
	-- part.Parent = workspace
	-- part.CFrame = CFrame.lookAt(originPos, originPos + dir) * CFrame.new(0, 0, -self.LineOfSight / 2)
	-- part.Size = Vector3.new(0.2, 0.2, self.LineOfSight)
	-- part.CanCollide = false
	-- part.CanQuery = false
	-- part.Anchored = true

	--Debris:AddItem(part, 1)

	if lineOfSight and (lineOfSight.Instance == target or lineOfSight.Instance.Parent == target) then
		--part.Color = Color3.fromRGB(0, 255, 0)
		return true
	end

	return false
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

		if self:IsTargetInView(candidate, target) then
			return candidate
		end
	end

	return nil
end
function RangeAI:StartAttackState(target: BasePart)
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

			-- Check if the NPC can see the player

			if self:IsTargetInView(self.Owner.BodyParts["RightUpperArm"].Position, target) then
				-- In valid range: stop, aim, and attack
				self:ToggleRightArmAimer(true)
				self:AimRightArmTowards(target)
				self:Attack()
			else
				warn("AI CANT SEE TARGET")
				task.spawn(function()
					local validPos = self:FindAnglePosition(charPos, target, attackDist)
					if validPos then
						AI.PathFindTo(self, validPos)
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
