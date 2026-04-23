local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local DestroyableData = require(ReplicatedStorage.Shared.DestroyableData)
local PoolHandler = require(StarterPlayer.StarterPlayerScripts.Client.Pools.PoolHandler)
local Particles = ReplicatedStorage.Shared.Effects
local EffectsDisplayer = {}

function EffectsDisplayer:DisplayBulletHole(position: CFrame?)
	if not position then
		warn("Client received an invalid cframeTarget when showing a bullet hole!")
		return
	end

	local availableBulletHole: Part = PoolHandler.BulletPool:Acquire()
	availableBulletHole:PivotTo(position)
end

function EffectsDisplayer:DisplayDestroyableExplosion(destroyableParticleName: string, position: Vector3)
	local explosion: Part = Instance.new("Part")
	if not destroyableParticleName then
		warn(`[CLIENT] Can't show explosion particle, missing explosion name data`)
		return
	end
	local particleEffect = if Particles[destroyableParticleName]
		then Particles[destroyableParticleName]:Clone()
		else nil

	explosion.Parent = workspace
	explosion.CanCollide = false
	explosion.CanQuery = false
	explosion.Transparency = 1
	explosion.Anchored = true
	explosion.Position = position
	particleEffect.Parent = explosion
	particleEffect:Emit(25)
	Debris:AddItem(explosion, 0.2)
end

-- For inflicting damage spread e.g fire
function EffectsDisplayer:DisplaySpreadParticle(destroyableParticleName: string, duration: number, parent: BasePart)
	if not destroyableParticleName then
		warn(`[CLIENT] Can't show explosion particle, missing explosion name data`)
		return
	end
	if not parent then
		return
	end

	local particleEffect = if Particles[destroyableParticleName]
		then Particles[destroyableParticleName]:Clone()
		else nil

	particleEffect.Parent = parent
	particleEffect:Emit(1)
	Debris:AddItem(particleEffect, duration)
end

function EffectsDisplayer:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "Can't apply blood to position, POSITION is nil on DisplayBloodHit")
	assert(normal, "Can't apply blood to position, normal is nil on DisplayBloodHit")

	local hitPos = CFrame.lookAt(position, position + normal)

	local availableBlood: Part = PoolHandler.BloodPool:Acquire()
	assert(availableBlood, "Can't find available blood from its pool, does it exist?")

	availableBlood:PivotTo(hitPos)

	-- enable blood and disable after a short time
	for _, particle in availableBlood:GetChildren() do
		particle:Emit(1)
	end
end

return EffectsDisplayer
