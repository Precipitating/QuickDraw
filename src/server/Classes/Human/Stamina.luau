local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
-- Stamina.luau

local Stamina = {}
Stamina.__index = Stamina

function Stamina.new(character: Model)
	local self = setmetatable({}, Stamina)
	self.Character = character
	self.Current = HumanConstants.MAX_STAMINA
	self.OnDepleted = Signal.new()
	self:_publish()
	return self
end

function Stamina:_publish()
	self.Character:SetAttribute("Stamina", self.Current)
end

-- Atomic check + deduct. Returns whether the action is allowed.
function Stamina:TryConsume(cost: number): boolean
	if self.Current < cost then
		return false
	end
	self.Current -= cost
	self:_publish()
	return true
end

function Stamina:Update(dt: number, sprinting: boolean)
	local delta = sprinting and -HumanConstants.STAMINA_DRAIN_RATE or HumanConstants.STAMINA_REGEN_RATE
	local before = self.Current
	self.Current = math.clamp(self.Current + delta * dt, 0, HumanConstants.MAX_STAMINA)

	-- fire once on the transition, not every frame while at 0
	if before > 0 and self.Current <= 0 then
		Utility.Warn(`Stamina depleted!`)
		self.OnDepleted:Fire()
	end
	self:_publish()
end

return Stamina
