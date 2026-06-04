local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RingBufferPool = require(ReplicatedStorage.Shared.Classes.RingBufferPool)

local function PoolInitialize(objectToPool: Instance, maxPoolAmount: number, folderName: string)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	return RingBufferPool.new(objectToPool, maxPoolAmount, folder)
end

local function PoolIntializeList(objectsToPool: {}, maxPoolAmount: number, folderName: string)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	return RingBufferPool.new(objectsToPool, maxPoolAmount, folder)
end

return {
	BulletPool = PoolInitialize(ReplicatedStorage.Shared.Templates.BulletHole, 50, "BulletHolePool"),
	BloodPool = PoolInitialize(ReplicatedStorage.Shared.Templates.Blood, 12, "BloodPool"),
	BurnMarksPool = PoolIntializeList(ReplicatedStorage.Shared.Templates.BurnMarks:GetChildren(), 20, "BurnMarksPool"),
	CannonHolePool = PoolInitialize(ReplicatedStorage.Shared.Templates.CannonHole, 50, "CannonHolePool"),
}
