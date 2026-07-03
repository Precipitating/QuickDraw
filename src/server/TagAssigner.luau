local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Destroyable = require(ServerScriptService.Server.Classes.Environment.Destroyable)
local TurretManager = require(ServerScriptService.Server.Classes.EnvironmentWeaponry.TurretManager)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)
local TagAssigner = {}

function TagAssigner.Initialize()
	local destroyable = CollectionService:GetTagged("Destroyable")
	for _, obj in destroyable do
		warn(`Initialize destroyable class on {obj.Name}`)
		local destroyableClass = Destroyable.new(obj)
		DestroyableManager:AddDestroyable(obj, destroyableClass)
	end
	CollectionService:GetInstanceAddedSignal("Destroyable"):Connect(function(obj: Instance)
		warn(`Initialize destroyable class on {obj.Name}`)
		local destroyableClass = Destroyable.new(obj)
		DestroyableManager:AddDestroyable(obj, destroyableClass)
	end)

	CollectionService:GetInstanceRemovedSignal("Destroyable"):Connect(function(obj: Instance)
		DestroyableManager:RemoveDestroyable(obj)
	end)

	CollectionService:GetInstanceAddedSignal("Turret"):Connect(function(obj: Instance)
		warn(`New turret instance detected! Initializing class!`)
		TurretManager:Register(obj)
	end)
	CollectionService:GetInstanceRemovedSignal("Turret"):Connect(function(obj: Instance)
		warn(`Turret instance removed! removing class!`)
		TurretManager:Unregister(obj)
	end)
end

return TagAssigner
