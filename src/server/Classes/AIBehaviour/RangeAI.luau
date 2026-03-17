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
			local distDiff = target:GetPivot().Position - character:GetPivot().Position
			local distSquared = distDiff:Dot(distDiff)
			if self.CurrentState ~= "Attack" then
				return
			end

			-- keep within attack distance

			if distSquared > ((attackDist + self.PathfindTolerance) ^ 2) then
				if not self.CurrentlyMoving then
					self:ToggleRightArmAimer(false)
					task.spawn(function()
						AI.PathFindTo(self, target:GetPivot().Position)
					end)
				end
				continue
			end

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
