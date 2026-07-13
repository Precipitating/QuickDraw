local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptHandler = require(script.Parent.Parent.ClientInputs.ProximityPromptHandler)
local ClientDigHandler = require(script.Parent.Parent.Dig.ClientDigHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientLootHandler = {}
ClientLootHandler.networker = Networker.new("LootNetwork", ClientLootHandler)

function ClientLootHandler:SellAllOres()
	local success = self.networker:fetch("SellAllOres")

	return success
end

function ClientLootHandler:PickupOre(prompt: ProximityPrompt)
	if PlayerContext.IsBusy then
		return
	end
	prompt.Enabled = false
	PlayerContext.IsBusy = true

	ClientDigHandler:StartDigging("Drill", "OreDrill")

	task.delay(5, function()
		ClientDigHandler:StopDigging()
		ProximityPromptHandler.networker:fire("LootPickup", "Ore", prompt)
		PlayerContext.IsBusy = false
	end)
end

return ClientLootHandler
