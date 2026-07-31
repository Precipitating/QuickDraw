local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BitPacker = require(ReplicatedStorage.Shared.BitPacker)

local NextID = 1

local OptimizedNPCHandler = {}
OptimizedNPCHandler.__index = OptimizedNPCHandler

OptimizedNPCHandler.Enemies = {}
OptimizedNPCHandler.InterpolationBlacklist = {}

function OptimizedNPCHandler.new(type: string, position: Vector3)
	local self = setmetatable({}, OptimizedNPCHandler)

	local model = ReplicatedStorage.Shared.Templates.HumanServerRig:Clone()
	model.Parent = workspace.Camera
	model.HumanoidRootPart.Position = Vector3.new(position.X, position.Y, position.Z)
	model.HumanoidRootPart:SetNetworkOwner(nil)

	self.ID = NextID
	NextID += 1
	self.model = model
	model.Name = self.ID

	OptimizedNPCHandler.Enemies[self.ID] = self

	return self
end

function OptimizedNPCHandler.ConstructRenderPacket()
	local packet = {}

	for _, enemy in pairs(OptimizedNPCHandler.Enemies) do
		local data = OptimizedNPCHandler.PackEnemy(
			enemy.ID,
			enemy.Model.HumanoidRootPart.Position,
			enemy.Model.HumanoidRootPart.Orientation.Y
		)

		packet[#packet + 1] = data
	end

	return packet
end
function OptimizedNPCHandler.PackEnemy(ID, position, orientation)
	orientation = math.floor((orientation % 360) / 360 * 255 + 0.5)
	local X = BitPacker.Unsign(math.floor(10 * position.X + 0.5), 13)
	local Y = BitPacker.Unsign(math.floor(10 * position.Y + 0.5), 13)
	local Z = BitPacker.Unsign(math.floor(10 * position.Z + 0.5), 13)

	return BitPacker.PackData(ID, orientation, X, Y, Z)
end

return OptimizedNPCHandler
