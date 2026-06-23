local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local DialogModule = require(script.Parent.DialogModule)
return {
	CitizenNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		if not npcModel or not prompt then
			error("Cannot initialize dialogue, missing refs")
			return
		end

		local guiName: TextLabel = Utility.GetInstance(npcModel, true, "Head", "gui", "name")

		if guiName then
			guiName.Text = "Citizen"
		end

		local dialogObject = DialogModule.new("Citizen", npcModel, prompt)
		dialogObject:addDialog("This town is crazy!", { "So you JUST noticed that?" })

		prompt.Triggered:Connect(function(player)
			dialogObject:triggerDialog(player, 1)
		end)

		dialogObject.responded:Connect(function(responseNum, dialogNum)
			if dialogNum == 1 then
				if responseNum == 1 then
					dialogObject:hideGui("I'm smarter than you, kid.")
				end
			end
		end)
	end,
	SusNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		if not npcModel or not prompt then
			error("Cannot initialize dialogue, missing refs")
			return
		end

		local guiName: TextLabel = Utility.GetInstance(npcModel, true, "Head", "gui", "name")

		if guiName then
			guiName.Text = "Suspicious Guy"
		end

		local dialogObject = DialogModule.new("Citizen", npcModel, prompt)
		dialogObject:addDialog("What you lookin' at?", { "N-nothing sire." })

		prompt.Triggered:Connect(function(player)
			dialogObject:triggerDialog(player, 1)
		end)

		dialogObject.responded:Connect(function(responseNum, dialogNum)
			if dialogNum == 1 then
				if responseNum == 1 then
					dialogObject:hideGui("Exactly.")
				end
			end
		end)
	end,
}
