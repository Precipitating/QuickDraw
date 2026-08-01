local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCTypesKeyed = require(ReplicatedStorage.Shared.NPCData.NPCs.NPCTypesKeyed)
local Sera = require(ReplicatedStorage.Shared.Sera)
local SeraSchemas = require(ReplicatedStorage.Shared.SeraSchemas)

local NextID = 1

local OptimizedNPCHandler = {}
OptimizedNPCHandler.__index = OptimizedNPCHandler

OptimizedNPCHandler.Enemies = {}
OptimizedNPCHandler.InterpolationBlacklist = {}

function OptimizedNPCHandler.new(position: Vector3)
	local self = setmetatable({}, OptimizedNPCHandler)

	local model = ReplicatedStorage.Shared.Templates.HumanServerRig:Clone()
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace.Camera

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end

	self.ID = NextID
	NextID += 1
	self.Model = model
	model.Name = self.ID
	self.Faction = nil

	OptimizedNPCHandler.Enemies[self.ID] = self

	return self
end

function OptimizedNPCHandler.ConstructRenderPacket()
	local packet = {}

	for idx, enemy in pairs(OptimizedNPCHandler.Enemies) do
		if CollectionService:HasTag(enemy.Model, "Dead") then
			OptimizedNPCHandler.Enemies[enemy.ID] = nil
			continue
		end

		local data = OptimizedNPCHandler.PackEnemy(enemy.ID, enemy.Model:GetPivot(), enemy.Faction)

		packet[#packet + 1] = data
	end

	return packet
end
function OptimizedNPCHandler.PackEnemy(ID: number, cframe: CFrame, faction: number)
	local buf, err = Sera.Serialize(SeraSchemas.NPCSchema, {
		ID = ID,
		CFrame = cframe,
		Faction = NPCTypesKeyed[faction],
	})
	if err then
		error(err)
	end

	return buf
end

return OptimizedNPCHandler
