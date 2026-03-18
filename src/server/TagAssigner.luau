local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Destroyable = require(ServerScriptService.Server.Classes.Environment.Destroyable)
local TagAssigner = {}

function TagAssigner.Initialize()
	local destroyable = CollectionService:GetTagged("Destroyable")
	for _, obj in pairs(destroyable) do
		warn(`Initialize destroyable class on {obj.Name}`)
		Destroyable.new(obj.Name)
	end
	CollectionService:GetInstanceAddedSignal("Destroyable"):Connect(function(obj: Instance)
		warn(`Initialize destroyable class on {obj.Name}`)
		Destroyable.new(obj.Name)
	end)
end

return TagAssigner
