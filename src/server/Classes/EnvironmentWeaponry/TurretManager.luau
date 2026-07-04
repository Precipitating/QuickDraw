local RunService = game:GetService("RunService")
local Turret = require(script.Parent.Turret)
local TurretManager = {}
local ActiveTurrets = {}
local Active = true
local LoopConnection = nil

function TurretManager:Register(model)
	local newTurret = Turret.new(model)
	ActiveTurrets[model] = newTurret
end

function TurretManager:Unregister(turretModel)
	local exists = ActiveTurrets[turretModel]

	if exists then
		warn("Removing turret...")
		ActiveTurrets[turretModel]:Destroy()
		ActiveTurrets[turretModel] = nil
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
	local existingInstances = workspace:QueryDescendants(".Turret")
	for _, turretModel in existingInstances do
		self:Register(turretModel)
	end
end

-- (TagAssigner module handles dynamically added turrets and class removal if turret destroyed)
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
