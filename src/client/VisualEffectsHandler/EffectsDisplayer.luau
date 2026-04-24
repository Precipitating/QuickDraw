local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PoolHandler = require(StarterPlayer.StarterPlayerScripts.Client.Pools.PoolHandler)
local Particles = ReplicatedStorage.Shared.Effects
local EffectsDisplayer = {}

EffectsDisplayer.networker = Networker.new("EffectsDisplayerNetwork", EffectsDisplayer)

function EffectsDisplayer:DisplayBulletHole(cframeTarget: CFrame?)
	if not cframeTarget then
		warn("Client received an invalid cframeTarget when showing a bullet hole!")
		return
	end

	local availableBulletHole: Part = PoolHandler.BulletPool:Acquire()
	availableBulletHole:PivotTo(cframeTarget)
end

function EffectsDisplayer:DisplayMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end
	local muzzleFolder = Utility.GetInstance(gunTool, true, "MuzzleFlash", "Attachment")

	if not muzzleFolder then
		return
	end

	for _, effect in muzzleFolder:GetChildren() do
		if effect:IsA("SpotLight") then
			effect.Enabled = true
			task.delay(0.1, function()
				if effect then
					effect.Enabled = false
				end
			end)
			continue
		end
		if not effect:IsA("ParticleEmitter") then
			continue
		end

		effect:Emit(1)
	end
end

function EffectsDisplayer:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
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
