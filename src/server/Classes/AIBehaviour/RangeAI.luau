local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Stack = require(ReplicatedStorage.Shared.Classes.Stack)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local NPCTypes = require(ReplicatedStorage.Shared.NPCData.NPCTypes)
local Fallback = require(ServerScriptService.Server.Classes.AIBehaviour.States.Fallback)
local Patrol = require(ServerScriptService.Server.Classes.AIBehaviour.States.Patrol)
local RangeAttack = require(ServerScriptService.Server.Classes.AIBehaviour.States.RangeAttack)
local Stalk = require(ServerScriptService.Server.Classes.AIBehaviour.States.Stalk)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)

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
	self.ThrowableAmmo = classData.ThrowableAmmo
	self.MaxThrowableAmmo = classData.MaxThrowableAmmo
	self.AttackState = (classData and classData.AttackStateName)
			and {
				Name = classData.AttackStateName,
				Data = (classData and classData.AttackStateData) or (optionalData and optionalData.AttackStateData),
			}
		or nil
	self.DefaultState = (classData and classData.DefaultStateName)
			and {
				Name = classData.DefaultStateName,
				Data = human.Character:GetAttribute("DefaultStateData")
					or (classData and classData.DefaultStateData)
					or (optionalData and optionalData.DefaultStateData),
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

-- Ensure the AI is within the shooting position
function RangeAI:CorrectRangePosition(targetPos: Vector3): string | boolean
	local currentPos = self.Owner.Character:GetPivot().Position
	local distance = (targetPos - currentPos).Magnitude
	local legless = self.Owner:IsLegless()
	-- Must be 5 studs PAST max before seeking, add a buffer to account for pathfinding inaccuracies
	if distance >= self.MaxAttackDistance + 5 then
		return "Seek"
	end
	-- Must be 5 studs PAST min before falling back
	if distance <= self.MinAttackDistance - 5 and not legless then
		return "Fallback"
	end
	if not legless then
		self:ChangeWalkSpeed(HumanConstants.WALKSPEED)
	end
	return true
end

function RangeAI:Attack()
	local human = self.Owner
	if not (human and human.Inventory) then
		return
	end

	local currentGun = human.Inventory:GetGun()
	if not currentGun then
		return
	end

	local tool = currentGun.Tool
	local handle = currentGun.Handle
	local shootPoint = currentGun.ShootPoint
	local rightArm = human.BodyParts.RightUpperArm

	if not (tool and handle and shootPoint and rightArm) then
		return
	end
	if currentGun.Reloading then
		return
	end

	if currentGun.CurrentAmmo <= 0 then
		currentGun:Reload()
	else
		currentGun:ShootGun()
		warn(`{self.Owner.Name} should shoot!`)
		local recoil = GunData[self.WeaponName].GunRecoil
		handle:ApplyImpulseAtPosition(handle.AssemblyMass * UP * recoil, shootPoint.WorldPosition)
	end
end

-- Get angle required for object to hit a position (if possible)
function RangeAI:GetThrowAngle(origin, target, velocity)
	local diff = target - origin
	local horizontalDist = Vector3.new(diff.X, 0, diff.Z).Magnitude
	local verticalDist = diff.Y
	local v2 = velocity * velocity
	local g = workspace.Gravity

	local discriminant = v2 * v2 - g * (g * horizontalDist * horizontalDist + 2 * verticalDist * v2)
	if discriminant < 0 then
		return nil, nil -- target out of range for this velocity
	end

	-- two solutions, low arc and high arc
	local lowArc = math.atan((v2 - math.sqrt(discriminant)) / (g * horizontalDist))
	local highArc = math.atan((v2 + math.sqrt(discriminant)) / (g * horizontalDist))

	return lowArc, highArc -- in radians
end
function RangeAI:ThrowThrowable(targetPos)
	local throwable = self.Owner.Inventory:GetThrowable()
	if not throwable then
		return false
	end
	if throwable.CurrentAmmo <= 0 then
		return false
	end

	local origin = self.Owner.BodyParts["RightHand"].Position

	local lowArc, _ = self:GetThrowAngle(origin, targetPos, throwable.Velocity)
	if not lowArc then
		return false
	end

	local toTargetDir = (targetPos - origin).Unit
	local throwDirection = (CFrame.new(Vector3.zero, toTargetDir) * CFrame.Angles(lowArc, 0, 0)).LookVector

	local thrown = throwable:Throw(throwDirection)
	return thrown
end

return RangeAI
