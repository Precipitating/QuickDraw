local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GunSignals = require(ServerScriptService.Server.Gun.GunSignals)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local DestroyableData = require(ReplicatedStorage.Shared.DestroyableData)
local Effects = ReplicatedStorage.Shared.Effects
-- Destroyable environmental objects that may produce a unique effect
local Destroyable = {}
Destroyable.__index = Destroyable

function Destroyable.new(object: Instance)
	assert(DestroyableData[object.Name], "Destroyable name doesn't exist to initialize")
	local self = setmetatable({}, Destroyable)
	local data = DestroyableData[object.Name]
	self.ModelRef = object
	self.Name = object.Name
	self.Health = data.Health
	self.Type = data.Type
	self.HumanEffect = data.HumanEffect
	self.Radius = data.Radius
	self.BaseDamage = data.Damage
	self.Particles = object:FindFirstChild("Particles")
	self.DestroyParticle = data.DestroyParticle
	self.SpreadParticle = if data.SpreadParticle then data.SpreadParticle else nil
	self.SpreadDuration = if data.SpreadDuration then data.SpreadDuration else nil
	return self
end

function Destroyable:Damage(damageAmount: number)
	self.Health = math.max(0, self.Health - damageAmount)

	if self.Health <= 0 then
		self:Destroy()
	end
end

function Destroyable:BodyPartDamage(damagedObject: Instance?)
	if not damagedObject then
		return false
	end

	local parent = damagedObject.Parent
	local humanoid = if parent then parent:FindFirstChild("Humanoid") else nil
	local isBodyPart = damagedObject:IsA("MeshPart") and humanoid

	if isBodyPart then
		if self.HumanEffect == "Spread" then
			GunSignals.InflictLimbDamage:Fire(
				damagedObject,
				self.BaseDamage,
				self.SpreadParticle,
				self.SpreadDuration or 1,
				humanoid
			)
		else
			if self.HumanEffect == "Damage" then
				GunSignals.InflictLimbDamage:Fire(damagedObject, self.BaseDamage, nil, 1, humanoid)
			end
		end
	end

	return true
end

function Destroyable:ApplyRadiusDamage()
	local partsInRadius = workspace:GetPartBoundsInRadius(self.ModelRef:GetPivot().Position, self.Radius)

	for _, obj in pairs(partsInRadius) do
		local hitBodyPart = self:BodyPartDamage(obj)
		if hitBodyPart then
			continue
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
	destroyEffect:Emit(1)

	Debris:AddItem(explosion, 0.3)
end

function Destroyable:Destroy()
	if not self.ModelRef then
		return
	end

	if self.Type == "Explosive" then
		ServerSoundHandler:Play3DOneShotToOthers(nil, "DynamiteExplosion", self.ModelRef.CFrame)
		self:ApplyRadiusDamage()
	end

	local destroyEffect = if self.DestroyParticle then Effects[self.DestroyParticle]:Clone() else nil

	if destroyEffect then
		self:SpawnDestroyVFX(destroyEffect)
	end

	self.ModelRef:Destroy()
end

return Destroyable
