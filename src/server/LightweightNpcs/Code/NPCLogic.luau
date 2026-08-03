local NpcTypes = require(script.Parent.NpcTypes)
local MathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)
local NPC_CULL_DISTANCE = 400
local NPCLogic = {}

function NPCLogic:OnSpawn(npcRecord: NpcTypes.npcRecordType)
	npcRecord.onThink:Connect(function(dt)
		if tick() > npcRecord.data.nextMove then
			npcRecord.data.nextMove = tick() + 0.5 + math.random()

			if math.random() > 0.5 then
				--idle
				npcRecord:Move(Vector3.zero)
				npcRecord:PlayAnimation("idle", false, 1, 1)
			else
				--run
				local ang = math.random() * math.pi * 2
				npcRecord:Move(MathUtils:PlayerAngleToVec(ang))
				npcRecord:PlayAnimation("walk", false, 1, 1)
			end
		end
	end)

	npcRecord.onCullCheck:Connect(function()
		--Basic culling, but you could technically mask NPCs to individual players
		--or anything else you want to do here
		for key, player in game.Players:GetPlayers() do
			if player.Character and player.Character.PrimaryPart then
				local bubbleVec = npcRecord.position - (player.Character.PrimaryPart :: any).Position

				if bubbleVec.Magnitude < NPC_CULL_DISTANCE then
					npcRecord:SetPlayerVisibleFlag(player, true)
				else
					npcRecord:SetPlayerVisibleFlag(player, false)
				end
			end
		end
	end)

	-- npcRecord.onBumpIntoWall:Connect(function(instance)
	-- 	--send an event to clients if we bump into something
	-- 	if npcRecord.instance then
	-- 		--This costs RECV, but flashes the NPCS white for fun
	-- 		npcRecord:AddClientEvent({ id = "Bump" })
	-- 	end
	-- 	npcRecord:Move(Vector3.zero)
	-- 	npcRecord:PlayAnimation("idle", false, 1, 1)
	-- end)
end

return NPCLogic
