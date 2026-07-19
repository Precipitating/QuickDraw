local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Animal class
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerScreenEffects = require(ServerScriptService.Server.ServerScreenEffects)
local Animal = require(script.Parent.Animal)

local Buffalo = setmetatable({}, Animal)
Buffalo.__index = Buffalo

function Buffalo.new(model: Model?, classType: string)
	local self = setmetatable(Animal.new(model, classType), Buffalo)
	self.ChargeDistance = 150
	self.ChargeForce = 100
	self.ChargeStartTime = 0
	self.WaitTimeBeforeCharge = 5
	return self :: any
end

-- Allows the ball sockets to wander freely after disabling the AnimationConstraints
-- Also enables collision on legs so legs dont go through ground
function Buffalo:DeathRagdoll()
	local character = self.Character
	if not character then
		return
	end
	-- Disable constraints
	for _, instance in self.Character:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.CollisionGroup = "Dead"
		end
		if instance:IsA("AnimationConstraint") then
			instance.Enabled = false
			if instance.Parent and instance.Parent:IsA("BasePart") then
				local parent = instance.Parent
				if not parent.CanCollide then
					parent.CanCollide = true
				end
			end
		end
	end
end

function Buffalo:ChargeUpRun(target: Model? | BasePart?, onComplete: () -> ())
	if not target then
		warn(`[LookAtTargetFor] Missing target reference`)
		return
	end

	self.Janitor:Add(
		RunService.Heartbeat:Connect(function()
			if os.clock() - self.ChargeStartTime >= self.WaitTimeBeforeCharge then
				warn("Charge ready")
				self.Janitor:Remove("LookAtConn")
				onComplete()
				return
			end
			local targetCFrame = target:GetPivot()
			self:SetFlattenedTorsoAimer(targetCFrame)
		end),
		"Disconnect",
		"LookAtConn"
	)
end

-- Run in a straight line towards target and connect its collider to apply damage if hit
function Buffalo:Attack(target: Model? | BasePart?, onComplete: () -> ())
	if self.Attacking then
		return
	end

	if not target then
		warn("Buffalo missing target, can't attack!")
		return
	end

	self.Attacking = true
	self.ChargeStartTime = os.clock()

	-- 1. Align Buffalo to look towards target for x seconds
	self:ChargeUpRun(target, function()
		local collider: BasePart = self.Character:FindFirstChild("HeadbuttCollider", true)
		if not collider then
			return
		end

		-- 2. Should call when charging has occured already, then go to seek state
		self.Janitor:Add(
			self.Humanoid.MoveToFinished:Once(function(reached)
				self.Attacking = false
				self.Janitor:Remove("AttackConn")
				onComplete()
			end),
			"Disconnect"
		)

		-- 3. Connect charge hitbox, applying damage to targets
		self.Janitor:Add(
			collider.Touched:Once(function(hitPart: BasePart)
				local parent = hitPart.Parent
				warn(`Buffalo hit {hitPart}`)
				local humanoid = parent:FindFirstChildOfClass("Humanoid")
				if
					parent
					and humanoid
					and (CollectionService:HasTag(parent, "NPC") or CollectionService:HasTag(parent, "Player"))
				then
					local humanClass = PlayerManager:GetHumanClass(humanoid)
					if not humanClass or not hitPart then
						return
					end
					local dir = (self.HRP.CFrame.LookVector + Vector3.new(0, 0.3, 0)).Unit
						* hitPart.AssemblyMass
						* self.ChargeForce

					if humanClass.Ragdoll then
						humanClass:Ragdoll(5)
					end
					task.defer(function()
						humanClass:ApplyImpulse(dir)
					end)

					local data = {
						Damage = HumanConstants.BUFFALO_DAMAGE,
						LimbHit = hitPart,
						TargetHuman = humanClass,
						CanAffectShooter = false,
						Shooter = self.Character,
					} :: ClassTypes.BargeDamage

					DamageModule.DamageHuman(data)
					ServerScreenEffects:ApplyOneShotEffect(humanClass.Player, "BullRam")
				else
					self:UpdateHealth(-HumanConstants.BUFFALO_DAMAGE)
				end
				self.Humanoid:MoveTo(self.HRP.Position)
			end),
			"Disconnect",
			"AttackConn"
		)

		-- charge
		local finalDest = self.HRP.Position + self.HRP.CFrame.LookVector * self.ChargeDistance
		self.Humanoid.WalkSpeed = self.AttackRunSpeed
		self.Humanoid:MoveTo(finalDest)
	end)
end
return Buffalo
