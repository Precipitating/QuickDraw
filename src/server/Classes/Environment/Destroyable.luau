local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerEffectsDisplayer = require(script.Parent.ServerEffectsDisplayer)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local NPCPhysics = require(ServerScriptService.Server.LightweightNpcs.Code.NPCPhysics)
local LightweightNpcsServerAPI = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ProjectileEvents = require(ServerScriptService.Server.ProjectilesHandler.ProjectileEvents)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local DestroyableData = require(ReplicatedStorage.Shared.DestroyableData)
local NpcState = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.NpcState)
-- Destroyable environmental objects that may produce a unique effect
local Destroyable = {}
Destroyable.__index = Destroyable

type Human = ClassTypes.Human
function Destroyable.new(object: Instance)
	assert(DestroyableData[object.Name], "Destroyable name doesn't exist to initialize")
	local self = setmetatable({}, Destroyable)
	local data = DestroyableData[object.Name]
	self.DestroyableData = data
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
	local npcClass = parent:GetAttribute("npcId") and LightweightNpcsServerAPI:GetNpcById(parent:GetAttribute("npcId"))
	if not humanClass and not npcClass then
		return
	end

	if (humanClass and humanClass.Dead) or (npcClass and npcClass.npcState == NpcState.Dying) then
		return
	end

	if
		(humanoid and humanoid:GetState() == Enum.HumanoidStateType.Ragdoll)
		or (npcClass and npcClass.npcState == NpcState.Ragdolled)
	then
		return
	end
	local force = 100

	local root = if humanClass then humanClass.HRP else npcClass.hrp
	if not root then
		warn(`Destroyable:ApplyHumanExplosionImpulse missing HRP reference!`)
		return
	end
	local dir = (root.Position - self.ModelRef:GetPivot().Position)
	local dirUpBias = (dir + vector.create(0, 3, 0)).Unit

	if humanClass then
		local impulse = dirUpBias * force * root.AssemblyMass
		humanClass:Ragdoll(3)
		humanClass:ApplyImpulse(impulse)
	elseif npcClass then
		local impulse = dirUpBias * force
		NPCPhysics:ApplyImpulse(npcClass, impulse)
		NPCPhysics:Ragdoll(npcClass, 3)
	end
end

function Destroyable:ApplyRadiusDamage()
	local modelPos = self.ModelRef:GetPivot().Position
	local partsInRadius = workspace:GetPartBoundsInRadius(modelPos, self.Radius)
	local humansHitAlready = {}

	for _, obj in partsInRadius do
		local hitHumanLimb = ProjectileEvents:BodyPartDamage(obj, self.DestroyableData, self.PlayerWhoDestroyed)
		if hitHumanLimb then
			local parent = obj.Parent
			if not parent then
				return
			end
			-- Players only
			if parent then
				if not humansHitAlready[parent] then
					self:ApplyHumanExplosionImpulse(obj)
					humansHitAlready[parent] = true
				end
			end
		end
	end
end

function Destroyable:Destroy()
	if not self.ModelRef then
		return
	end

	if self.Type == "Explosive" then
		ServerSoundHandler:Play3DOneShotToOthers(
			nil,
			"DynamiteExplosion",
			self.ModelRef.CFrame.Position,
			{ MaxDistance = 500 }
		)
		self:ApplyRadiusDamage()
	end

	if self.DestroyParticle then
		ServerEffectsDisplayer:DisplayDestroyParticle(self.DestroyParticle, self.ModelRef:GetPivot().Position)
	end

	self.ModelRef:Destroy()
end

return Destroyable
