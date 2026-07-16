local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local AnimalAI = require(ServerScriptService.Server.Classes.AIBehaviour.AnimalAI)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local AnimalData = require(script.Parent.AnimalData)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Animal = {}
Animal.__index = Animal

function Animal.new(model: Model?, type: string)
	local self = setmetatable({}, Animal)
	assert(model, "Missing animal model")
	assert(type, "Missing animal type")
	local animalData = AnimalData[type]
	if not animalData then
		warn("Animal type does not exist!")
		return
	end

	self.Character = model
	self.Name = model.Name
	self.Janitor = Janitor.new()
	self.IsRagdolled = false
	self.Health = animalData.Health
	self.Attacking = false
	self.Target = workspace:FindFirstChild("Target")
	self.ClassType = "Animal"
	self.Type = type
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.HRP = model:FindFirstChild("HumanoidRootPart")
	self.BodyParts = {
		Head = Utility.GetInstance(model, false, "Head"),
		Body = Utility.GetInstance(model, false, "Body"),
	}
	self.TorsoAimer = self:InitializeTorsoAimer()
	self.AttackRunSpeed = animalData.AttackRunSpeed

	self.AI = AnimalAI.new(self, type)
	self.VoicelineSound = self:SetupVoicelineSound()
	self:Initialize()

	return self
end
function Animal:SetupVoicelineSound()
	local sound = Instance.new("Sound")
	sound.Name = "VoicelineSound"
	sound.Parent = self.HRP
	return sound
end
function Animal:InitializeTorsoAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = self.HRP.RootRigAttachment
	aimer.RigidityEnabled = true
	aimer.AlignType = Enum.AlignType.AllAxes
	aimer.Name = "TorsoAimer"
	aimer.Responsiveness = 150
	aimer.Enabled = false
	aimer.Parent = self.HRP
	return aimer
end

local function FlattenCFrameY(originalCFrame: CFrame): CFrame
	local lookVector = originalCFrame.LookVector
	-- Calculate the angle on the flat X/Z plane
	local yaw = math.atan2(-lookVector.X, -lookVector.Z)

	-- Create a new CFrame with only the Y rotation (yaw) and original position
	return CFrame.new(originalCFrame.Position) * CFrame.Angles(0, yaw, 0)
end

function Animal:UpdateHealth(value: number)
	self.Health += value

	if self.Health <= 0 then
		self:Die()
	end
end

function Animal:Die()
	self:Destroy()
end

function Animal:Attack()
	if self.Attacking then
		return false
	end
	self.Attacking = true
	if self.Name == "Buffalo" then
		local collider: BasePart = self.Character:FindFirstChild("HeadbuttCollider", true)
		if not collider then
			return false
		end

		self.Janitor:Add(
			self.Humanoid.MoveToFinished:Connect(function(reached)
				self.Attacking = false
				self.Janitor:Remove("AttackConn")
			end),
			"Disconnect"
		)

		-- connect charge hitbox
		self.Janitor:Add(
			collider.Touched:Once(function(hitPart: BasePart)
				local parent = hitPart.Parent
				local humanoid = parent:FindFirstChildOfClass("Humanoid")
				if
					parent
					and humanoid
					and (CollectionService:HasTag(parent, "NPC") or CollectionService:HasTag(parent, "Player"))
				then
					local humanClass = PlayerManager:GetHumanClass(humanoid)

					if not humanClass then
						return
					end
					local dir: Vector3 = (hitPart.Position - collider.Position).Unit
						* humanClass.HRP.AssemblyMass
						* 1000
					humanClass:ApplyImpulse(dir)

					local data = {
						Damage = HumanConstants.BUFFALO_DAMAGE,
						LimbHit = hitPart,
						TargetHuman = humanClass,
						CanAffectShooter = false,
						Shooter = self.Character,
					} :: ClassTypes.BargeDamage

					DamageModule.DamageHuman(data)
				else
					self.Health -= HumanConstants.BUFFALO_DAMAGE
				end
				self.Humanoid:MoveTo(self.HRP.Position)
			end),
			"Disconnect",
			"AttackConn"
		)

		-- charge
		local chargeDistance = 250
		local finalDest = self.HRP.Position + self.HRP.CFrame.LookVector * chargeDistance
		self.Humanoid.WalkSpeed = 100
		self.Humanoid:MoveTo(finalDest)
	end
	return true
end

function Animal:ToggleTorsoAimer(enable: boolean)
	local torsoAimer = self.TorsoAimer
	assert(torsoAimer, "[Animal:ToggleTorsoAimer] torsoAimer is nil")
	if torsoAimer.Enabled == enable then
		return
	end

	torsoAimer.Enabled = enable

	if not enable then
		torsoAimer.CFrame = CFrame.identity
	end

	--warn(`TorsoAimer new state = {torsoAimer.Enabled}`)
end

function Animal:SetFlattenedTorsoAimer(targetCFrame: CFrame)
	if not self or not self.TorsoAimer or not self.HRP then
		return false
	end

	local originPosition = self.HRP.Position
	local lookAt = CFrame.lookAt(originPosition, targetCFrame.Position)

	self:ToggleTorsoAimer(true)
	self.TorsoAimer.CFrame = FlattenCFrameY(lookAt)

	repeat
		task.wait()
	until not self.HRP or Utility.IsVectorNear(self.HRP.AssemblyAngularVelocity, 0.05)

	return true
end
--
function Animal:Initialize() end

function Animal:Destroy()
	self.Janitor:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end
return Animal
