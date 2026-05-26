local CollectionService = game:GetService("CollectionService")
local DoorHandler = {}

function DoorHandler:Initialize()
	local doors = CollectionService:GetTagged("Door")

	for _, door in doors do
		door.Touched:Connect(function(hit)
			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				door:SetNetworkOwner(player)
			end
		end)
	end
end
return DoorHandler
