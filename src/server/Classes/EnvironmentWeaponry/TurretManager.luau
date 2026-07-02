local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Turret = require(script.Parent.Turret)
local TurretManager = {}

local ActiveTurrets = {}
local Active = true
local LoopConnection = nil

function TurretManager:Register(turret)
	table.insert(ActiveTurrets, turret)
end

function TurretManager.Unregister(turret)
	local index = table.find(ActiveTurrets, turret)
	if index then
		table.remove(ActiveTurrets, index)
	end
end

function TurretManager:SetActive(active: boolean)
	Active = active

	if active then
		TurretManager:Initialize()
	else
		LoopConnection:Disconnect()
	end
end

function TurretManager:InitializeExistingTurrets()
	local existingInstances = CollectionService:GetTagged("Turret")

	for _, turret in existingInstances do
		local newTurret = Turret.new(turret)
		self:Register(newTurret)
	end
end

function TurretManager:Initialize()
	self:InitializeExistingTurrets()

	LoopConnection = RunService.Heartbeat:Connect(function(dt)
		if not Active then
			return
		end
		for _, turret in ActiveTurrets do
			turret:Update(dt)
		end
	end)
end

return TurretManager
