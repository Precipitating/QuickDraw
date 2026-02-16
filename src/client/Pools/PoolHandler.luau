local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RingBufferPool = require(ReplicatedStorage.Shared.Classes.RingBufferPool)

local function PoolInitialize(objectToPool: Instance, maxPoolAmount: number, folderName: string)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	return RingBufferPool.new(objectToPool, maxPoolAmount, folder)
end

return {
	BulletPool = PoolInitialize(ReplicatedStorage.Shared.Templates.BulletHole, 12, "BulletHolePool"),
	BloodPool = PoolInitialize(ReplicatedStorage.Shared.Templates.Blood, 12, "BloodPool"),
}
