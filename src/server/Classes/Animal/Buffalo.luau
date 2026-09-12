local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Animal class
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local LightweightNpcTypes = require(ServerScriptService.Server.LightweightNpcs.Code.LightweightNpcTypes)
local NPCHealth = require(ServerScriptService.Server.LightweightNpcs.Code.NPCHealth)
local NPCPhysics = require(ServerScriptService.Server.LightweightNpcs.Code.NPCPhysics)
local LightweightNpcsServerAPI = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerScreenEffects = require(ServerScriptService.Server.ServerScreenEffects)

local Animal = require(script.Parent.Animal)
local Buffalo = setmetatable({}, Animal)
Buffalo.__index = Buffalo

function Buffalo.new(model: Model?)
	local self = setmetatable(Animal.new(model, "Buffalo", true), Buffalo)
	if not model then
		warn("Buffalo missing model")
		return
	end
	self.ChargeDistance = 150
	self.ChargeForce = 200
	self.Type = "Buffalo"

	self.BodyParts = {
		Head = Utility.GetInstance(model, false, "Head"),
		Body = Utility.GetInstance(model, false, "Body"),
	}

	self.ChargeStartTime = 0
	self.WaitTimeBeforeCharge = 5
	return self :: any
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
	AnimationHandler:SetAnimationFolder(nil, "BuffaloChargeUpAnimations", self.Character)

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
				local npcId = hitPart.Parent and hitPart.Parent:GetAttribute("npcId")
				if
					parent
					and (humanoid or npcId)
					and (CollectionService:HasTag(parent, "NPC") or CollectionService:HasTag(parent, "Player"))
				then
					local humanClass = PlayerManager:GetHumanClass(humanoid)

					local npcClass: LightweightNpcTypes.npcRecordType? = npcId
						and LightweightNpcsServerAPI:GetNpcById(npcId)
					if (not humanClass and not npcClass) or not hitPart then
						return
					end

					local data = {
						Type = "Barge",
						Damage = HumanConstants.BUFFALO_DAMAGE,
						LimbHit = hitPart,
						TargetHuman = humanClass or npcClass,
						CanAffectShooter = false,
						Shooter = self.Character,
					} :: ClassTypes.BargeDamage

					-- Hits player:
					if humanClass then
						DamageModule.DamageHuman(data)
						ServerScreenEffects:ApplyOneShotEffect(humanClass.Player, "BullRam")

						if humanClass.Ragdoll then
							humanClass:Ragdoll(5)
						end
					elseif npcClass then
						npcClass.onHit:Fire(data)
						if npcClass.onRagdoll then
							npcClass.onRagdoll:Fire(5)
						end
					end

					local dir = (self.HRP.CFrame.LookVector + vector.create(0, 0.3, 0)).Unit
						* self.HRP.AssemblyMass
						* self.ChargeForce
					task.defer(function()
						if humanClass then
							humanClass:ApplyImpulse(dir)
						elseif npcClass then
							npcClass.onImpulse:Fire(dir)
						end
					end)
				else
					self:UpdateHealth(-HumanConstants.BUFFALO_DAMAGE)
				end

				AnimationHandler:ResetToDefaultAnimations(nil, self.Character)

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
