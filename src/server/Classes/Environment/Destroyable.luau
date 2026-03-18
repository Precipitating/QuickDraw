local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local DestroyableData = require(ReplicatedStorage.Shared.DestroyableData)
-- Destroyable environmental objects that may produce a unique effect
local Environment = ServerStorage.Environment
local Destroyable = {}
Destroyable.__index = Destroyable

function Destroyable.new(name: string)
	assert(DestroyableData[name], "Destroyable name doesn't exist to initialize")
	local self = setmetatable({}, Destroyable)
	local data = DestroyableData[name]
	self.ModelRef = Environment:FindFirstChild(name)
	self.Name = name
	self.Health = data.Health
	self.Type = data.Type
	self.HumanEffect = data.HumanEffect

	return self
end

function Destroyable:Damage(damageAmount: number)
	self.Health = math.max(0, self.Health - damageAmount)

	if self.Health <= 0 then
		self:Destroy()
	end
end

function Destroyable:Destroy()
	if not self.ModelRef then
		return
	end

	if self.Type == "Explosive" then
		ServerSoundHandler:Play3DOneShotToOthers(nil, "DynamiteExplosion", self.Model.Position)

		if self.HumanEffect == "Fire" then
			local molotov = Throwable.new("Molotov", nil)
			molotov:SpawnFragments(self.ModelRef.Position)
			molotov:Remove()
		end
	end

	self.ModelRef:Destroy()
end

return Destroyable
