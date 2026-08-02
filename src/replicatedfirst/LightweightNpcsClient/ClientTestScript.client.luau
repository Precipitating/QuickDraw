local clientNpcModule = require(script.Parent.Code.LightweightNpcsClientModule)
local ClientNpcTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.ClientNpcTypes)

clientNpcModule.onNpcLoad:Connect(function(npcRecord : ClientNpcTypes.clientNpcRecordType)

	npcRecord.onCustomEvent:Connect(function(event:any, serverTime: number)

		if (event.id == "Bump") then

			if (npcRecord.instance) then
				local head = npcRecord.instance:FindFirstChild("Head",true) :: BasePart
				if (head) then
					head.Color = Color3.new(1,1,1)
					task.spawn(function()
						task.wait(0.1)
						head.Color = BrickColor.Yellow().Color
					end)
				end
			end
		end
	end)
end)