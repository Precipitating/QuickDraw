local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local PoolHandler = require(StarterPlayer.StarterPlayerScripts.Client.Pools.PoolHandler)
local Particles = ReplicatedStorage.Shared.Effects
local EffectsDisplayer = {}

EffectsDisplayer.networker = Networker.new("EffectsDisplayerNetwork", EffectsDisplayer)

function EffectsDisplayer:GetHoleCFrame(position: Vector3, normal: Vector3): CFrame
	local up = Vector3.new(0, 1, 0)
	if math.abs(normal:Dot(up)) > 0.99 then
		up = Vector3.new(1, 0, 0)
	end
	local right = normal:Cross(up).Unit
	local adjustedUp = right:Cross(normal).Unit
	return CFrame.fromMatrix(position + normal * 0.05, right, adjustedUp, -normal)
end

local function TeleportAndWeld(part: Part, targetCFrame: CFrame, weldTarget: BasePart)
	part.Anchored = true
	local weld: WeldConstraint? = part:FindFirstChildOfClass("WeldConstraint")
	if not weld then
		return
	end
	weld.Enabled = false
	part.CFrame = targetCFrame

	weld.Part0 = part
	weld.Part1 = weldTarget
	weld.Enabled = true
	part.Anchored = false
end

function EffectsDisplayer:DisplayProjectileMark(name: string, result: RaycastResult)
	if not result then
		warn("Client received an invalid RaycastResult when showing a projectile mark!")
		return
	end

	local hitPos = self:GetHoleCFrame(result.Position, result.Normal)

	if name == "Bullet" then
		local availableBulletHole: Part = PoolHandler.BulletPool:Acquire(hitPos.Position)
		if availableBulletHole then
			TeleportAndWeld(availableBulletHole, hitPos, result.Instance)
		end
	elseif name == "Burn" then
		local availableBurnMark: Part = PoolHandler.BurnMarksPool:Acquire(hitPos.Position)
		if availableBurnMark then
			TeleportAndWeld(availableBurnMark, hitPos, result.Instance)
		end
	end
end

function EffectsDisplayer:DisplayMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end

	local muzzleFlash = gunTool:FindFirstChild("MuzzleFlash")
	if not muzzleFlash then
		return
	end
	local muzzleFlashAttachment = muzzleFlash:FindFirstChildOfClass("Attachment")
	if not muzzleFlashAttachment then
		return
	end

	for _, effect in muzzleFlashAttachment:GetChildren() do
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

-- for destroyables
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
	task.wait(0.1)
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

	if not availableBlood then
		return
	end

	availableBlood:PivotTo(hitPos)

	-- enable blood and disable after a short time
	for _, particle in availableBlood:GetChildren() do
		particle:Emit(1)
	end
end

return EffectsDisplayer
