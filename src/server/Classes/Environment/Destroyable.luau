local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local DestroyableData = require(ReplicatedStorage.Shared.DestroyableData)
local Effects = ReplicatedStorage.Shared.Effects
-- Destroyable environmental objects that may produce a unique effect
local Destroyable = {}
Destroyable.__index = Destroyable

type Human = ClassTypes.Human
function Destroyable.new(object: Instance)
	assert(DestroyableData[object.Name], "Destroyable name doesn't exist to initialize")
	local self = setmetatable({}, Destroyable)
	local data = DestroyableData[object.Name]
	self.ModelRef = object
	self.Name = object.Name
	self.Health = data.Health
	self.Type = data.Type
	self.HumanEffect = data.HumanEffect
	self.PlayerWhoDestroyed = nil
	self.Radius = data.Radius
	self.BaseDamage = data.Damage
	self.Particles = object:FindFirstChild("Particles")
	self.DestroyParticle = data.DestroyParticle
	self.SpreadParticle = if data.SpreadParticle then data.SpreadParticle else nil
	self.SpreadDuration = if data.SpreadDuration then data.SpreadDuration else nil
	return self
end

function Destroyable:Damage(damageAmount: number, shooter: Player?)
	self.Health = math.max(0, self.Health - damageAmount)

	if self.Health <= 0 then
		self.PlayerWhoDestroyed = shooter
		self:Destroy()
	end
end

function Destroyable:ApplyHumanExplosionImpulse(damagedObject: BasePart)
	local parent = damagedObject.Parent
	local humanoid = if parent then parent:FindFirstChild("Humanoid") else nil
	local humanClass = if humanoid then PlayerManager:GetHumanClass(humanoid) else nil

	if not humanClass then
		return
	end

	if humanClass.Dead then
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
		return
	end

	local root = humanClass.HRP
	local dir = (root.Position - self.ModelRef:GetPivot().Position)
	local dirUpBias = (dir + Vector3.new(0, 3, 0)).Unit

	local force = 100
	local impulse = dirUpBias * force * root.AssemblyMass

	humanClass:Ragdoll(3)
	humanClass:ApplyImpulse(impulse)
end

function Destroyable:BodyPartDamage(damagedObject: BasePart?)
	if not damagedObject then
		return false
	end

	local parent = damagedObject.Parent
	local humanoid = if parent then parent:FindFirstChild("Humanoid") else nil
	local isBodyPart = damagedObject:IsA("MeshPart") and humanoid

	if isBodyPart then
		if self.HumanEffect == "Spread" then
			GunSignals.InflictLimbDamage:Fire(
				self.SpreadParticle,
				self.SpreadDuration or 1,
				self.BaseDamage,
				damagedObject,
				humanoid,
				self.PlayerWhoDestroyed
			)
		else
			if self.HumanEffect == "Damage" then
				GunSignals.InflictLimbDamage:Fire(
					nil,
					1,
					self.BaseDamage,
					damagedObject,
					humanoid,
					self.PlayerWhoDestroyed
				)
			end
		end
		return true
	end
	return false
end

function Destroyable:ApplyRadiusDamage()
	local modelPos = self.ModelRef:GetPivot().Position
	local partsInRadius = workspace:GetPartBoundsInRadius(modelPos, self.Radius)
	local humansHitAlready = {}

	for _, obj in partsInRadius do
		if self:BodyPartDamage(obj) then
			local humanoid = if obj.Parent then obj.Parent:FindFirstChild("Humanoid") else nil
			if humanoid and not humansHitAlready[humanoid] then
				self:ApplyHumanExplosionImpulse(obj)
				humansHitAlready[humanoid] = true
			end
		end
	end
end

function Destroyable:SpawnDestroyVFX(destroyEffect: ParticleEmitter)
	local cframe: CFrame = self.ModelRef:GetPivot()
	local pos: Vector3 = cframe.Position

	local explosion: Part = Instance.new("Part")
	explosion.Parent = workspace
	explosion.CanCollide = false
	explosion.CanQuery = false
	explosion.Transparency = 1
	explosion.Anchored = true
	explosion.Position = pos
	destroyEffect.Parent = explosion
	destroyEffect:Emit(25)

	Debris:AddItem(explosion, 0.2)
end

function Destroyable:Destroy()
	if not self.ModelRef then
		return
	end

	if self.Type == "Explosive" then
		ServerSoundHandler:Play3DOneShotToOthers(nil, "DynamiteExplosion", self.ModelRef.CFrame, { MaxDistance = 500 })
		self:ApplyRadiusDamage()
	end

	local destroyEffect = if self.DestroyParticle then Effects[self.DestroyParticle]:Clone() else nil

	if destroyEffect then
		self:SpawnDestroyVFX(destroyEffect)
	end

	self.ModelRef:Destroy()
end

return Destroyable
