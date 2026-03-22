local DestroyableManager = {}
DestroyableManager.Destroyables = {}

function DestroyableManager:AddDestroyable(instance: Instance, destroyableClass)
	self.Destroyables[instance] = destroyableClass
end

function DestroyableManager:RemoveDestroyable(instance: Instance)
	if not self.Destroyables[instance] then
		warn("Failed to remove destroyable class, not valid")
		return
	end
	self.Destroyables[instance] = nil
end

function DestroyableManager:GetDestroyable(key: Instance)
	return self.Destroyables[key]
end

return DestroyableManager
