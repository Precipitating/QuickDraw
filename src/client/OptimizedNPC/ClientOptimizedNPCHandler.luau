local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BitPacker = require(ReplicatedStorage.Shared.BitPacker)
local OptimizedNPCHandler = require(ReplicatedStorage.Shared.OptimizedNPC.OptimizedNPCHandler)
local ClientRigs = ReplicatedStorage.Shared.NPCData.NPCs.Humans
local EnemyRenderEvent = ReplicatedStorage.EnemyRender

local interpolations = {}

local function InterpolatePart(part, startCFrame, endCFrame)
	interpolations[part] = {
		startCF = startCFrame,
		endCF = endCFrame,
		elapsed = 0,
	}
end

local function UnpackEnemy(data)
	local ID, orientation, X, Y, Z = BitPacker.UnpackData(data)
	local enemy = {}
	enemy.ID = ID
	enemy.position = Vector3.new(BitPacker.Sign(X / 10, 13), BitPacker.Sign(Y / 10, 13), BitPacker.Sign(Z / 10, 13))
	enemy.orientation = BitPacker.Sign(orientation / 255 * 360, 8)

	return enemy
end

local function onEnemyRender(packet)
	for _, entry in pairs(packet) do
		local enemy = UnpackEnemy(entry)
		local targetCFrame = CFrame.new(enemy.position) * CFrame.Angles(0, math.rad(enemy.orientation), 0)

		if not OptimizedNPCHandler.Enemies[enemy.ID] then
			local render = ClientRigs.CowboyNPC:Clone()
			render.Parent = workspace.Enemies
			render.Name = enemy.ID
			OptimizedNPCHandler.Enemies[enemy.ID] = {}
			OptimizedNPCHandler.Enemies[enemy.ID].render = render
			OptimizedNPCHandler.Enemies[enemy.ID].currentCFrame = targetCFrame
			render.Torso.CFrame = targetCFrame
		else
			local data = OptimizedNPCHandler.Enemies[enemy.ID]
			InterpolatePart(data.render.Torso, data.currentCFrame, targetCFrame)
			data.currentCFrame = targetCFrame
		end
	end
end

RunService.RenderStepped:Connect(function(deltatime)
	for part, data in pairs(interpolations) do
		data.elapsed += deltatime
		local alpha = math.clamp(data.elapsed / 0.1, 0, 1)
		part.CFrame = data.startCF:Lerp(data.endCF, alpha)
		if alpha >= 1 then
			interpolations[part] = nil
		end
	end
end)

EnemyRenderEvent.OnClientEvent:Connect(onEnemyRender)
