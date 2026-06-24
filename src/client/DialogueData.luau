local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ClientSoundHandler = require(StarterPlayer.StarterPlayerScripts.Client.Sound.ClientSoundHandler)
local DialogModule = require(ReplicatedStorage.Shared.DialogModule)
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ScreenEffects = require(script.Parent.Screen.ScreenEffects)
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
					dialogObject:hideGui("Im outta here!")
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
			guiName.FontFace = Font.fromName("RomanAntique")
			guiName.Text = "Suspicious Guy"
		end

		local dialogObject = DialogModule.new("Suspicious Guy", npcModel, prompt)

		-- EACH NEW DIALOG + 1 TO DIALOGNUM
		dialogObject:addDialog("What you lookin' at?", { "You bud.", "N-nothing sire." })
		dialogObject:addDialog(
			"You think you're funny, cowboy?",
			{ "Yeah, what you gonna do about it?", "No sir I was joking please forgive me." }
		)

		prompt.Triggered:Connect(function(player)
			dialogObject:triggerDialog(player, 1)
		end)

		dialogObject.responded:Connect(function(responseNum, dialogNum)
			if dialogNum == 1 then
				if responseNum == 1 then
					dialogObject:triggerDialog(PlayerContext.Player, 2)
				elseif responseNum == 2 then
					dialogObject:hideGui("Exactly.")
				end
			elseif dialogNum == 2 then
				if responseNum == 1 then
					dialogObject:hideGui("Look behind you.")
					task.wait(0.5)
					ScreenEffects:ToggleBlackScreen(0, 0)
					ClientSoundHandler:PlayKeyed("SFX", "LimbDismember")
					if PlayerContext.Humanoid and PlayerContext.Humanoid.Health then
						PlayerContext.Humanoid.Health = 0
					end
				elseif responseNum == 2 then
					dialogObject:hideGui("Exactly, trot off little piggy...")
				end
			end
		end)
	end,
}
