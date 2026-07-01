local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestGUIHandler = require(script.Parent.GUI.QuestGUIHandler)
local ClientSoundHandler = require(script.Parent.Sound.ClientSoundHandler)
local CoreGUIHandler = require(script.Parent.Utility.CoreGUIHandler)
local DialogModule = require(ReplicatedStorage.Shared.DialogModule)
local PlayerContext = require(script.Parent.Utility.PlayerContext)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local ScreenEffects = require(script.Parent.Screen.ScreenEffects)

-- ─── Types ────────────────────────────────────────────────────────────────────

type DialogEntry = {
	text: string,
	responses: { string },
}

-- [dialogNum][responseNum] → handler
type ResponseMap = { [number]: { [number]: (dialog: any) -> () } }

type NPCConfig = {
	name: string,
	font: string?, -- optional; omit to keep default font
	dialogs: { DialogEntry },
	responses: ResponseMap,
}

-- ─── Factory ──────────────────────────────────────────────────────────────────

local function InitNPC(npcModel: Model?, prompt: ProximityPrompt?, config: NPCConfig)
	if not npcModel or not prompt then
		error("Cannot initialize dialogue, missing refs")
		return
	end

	local guiName: TextLabel = Utility.GetInstance(npcModel, true, "Head", "gui", "name")
	if guiName then
		guiName.Text = config.name
		if config.font then
			guiName.FontFace = Font.fromName(config.font)
		end
	end

	local dialogObject = DialogModule.new(config.name, npcModel, prompt)

	for _, entry in config.dialogs do
		dialogObject:addDialog(entry.text, entry.responses)
	end

	prompt.Triggered:Connect(function(player)
		dialogObject:triggerDialog(player, 1)
		CoreGUIHandler.ToggleBackpackVisibility(false, true)
		if PlayerContext.Humanoid then
			PlayerContext.Humanoid:UnequipTools()
		end
		PlayerContext.IsBusy = true
	end)
	dialogObject.closed:Connect(function()
		CoreGUIHandler.ToggleBackpackVisibility(true, false)
		PlayerContext.IsBusy = false
	end)

	dialogObject.responded:Connect(function(responseNum: number, dialogNum: number)
		local handler = (config.responses[dialogNum] or {})[responseNum]
		if handler then
			handler(dialogObject)
		end
	end)
end

-- ─── NPC Definitions ──────────────────────────────────────────────────────────

return {
	CitizenNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "Citizen",
			dialogs = {
				{ text = "This town is crazy!", responses = { "So you JUST noticed that?" } },
			},
			responses = {
				[1] = {
					[1] = function(d)
						d:hideGui("Im outta here!")
					end,
				},
			},
		})
	end,

	SusNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "Suspicious Guy",
			font = "RomanAntique",
			dialogs = {
				{
					text = "What you lookin' at?",
					responses = { "You bud.", "N-nothing sire." },
				},
				{
					text = "You think you're funny, cowboy?",
					responses = { "Yeah, what you gonna do about it?", "No sir I was joking please forgive me." },
				},
			},
			responses = {
				[1] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 2)
					end,
					[2] = function(d)
						d:hideGui("Exactly.")
					end,
				},
				[2] = {
					[1] = function(d)
						d:hideGui("Look behind you.")
						task.wait(0.5)
						ScreenEffects:ToggleBlackScreen(0, 0)
						ClientSoundHandler:PlayKeyed("SFX", "LimbDismember")
						if PlayerContext.Humanoid and PlayerContext.Humanoid.Health then
							PlayerContext.Humanoid.Health = 0
						end
						-- d.fireClosed:Fire()
					end,
					[2] = function(d)
						d:hideGui("Exactly, trot off little piggy...")
					end,
				},
			},
		})
	end,

	DeadTownNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "???",
			font = "RomanAntique",
			dialogs = {
				{
					text = "Welcome to Deadtown.",
					responses = { "Anything here?", "Thank ya" },
				},
				{
					text = "The town name says it all.<br/>It's a ghost town, abandoned after the gold miners dipped after milking this place dry.",
					responses = { "So why are you here?", "Don't care, bye." },
				},
				{
					text = "Heard rumours of the 'Ghost of Wilson' haunting this place.<br/>Shots and explosions were heard at night sometimes, but all I see are abandoned homes.",
					responses = { "Shots?", "I'm scared now, bye." },
				},
				{
					text = "They say the 'Ghost of Wilson' was once a mad tinkerer, creating peculiar weaponry that always ends up explodin' the wielder.<br/>The shots and explosions are the sounds that occured before their inevitable death.",
					responses = { "Scary!", "I'm outta here now!" },
				},
				{
					text = "I came to confirm these rumours, but all I hear is silence.<br/>Don't worry about it kid and skip this town.",
					responses = { "Hmm. Okay." },
				},
			},
			responses = {
				[1] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 2)
					end,
					[2] = function(d)
						d:hideGui("Happy trails.")
					end,
				},
				[2] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 3)
					end,
					[2] = function(d)
						d:hideGui("You're a bull in a china sharp aren't ya?")
					end,
				},
				[3] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 4)
					end,
					[2] = function(d)
						d:hideGui("Heh, scared little pipsqueak.")
					end,
				},
				[4] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 5)
					end,
					[2] = function(d)
						d:hideGui("Run, desert, run!")
					end,
				},
				[5] = {
					[1] = function(d)
						d:hideGui("Good choice.")
					end,
				},
			},
		})
	end,

	BountyTipsNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "Bounty Guide",
			font = "RomanAntique",
			dialogs = {
				{
					text = "Want to know all there is to bounties?",
					responses = { "Yes", "No" },
				},
				{
					text = "It's simple your bounty goes up if you kill other people, but thats not all...",
					responses = { "What do you mean?" },
				},
				{
					text = "Having a bounty means sheriffs will target you, jailing you when they succesfully 'capture' you.",
					responses = { "How do I get rid of my bounty?" },
				},
				{
					text = "Someone has to claim your bounty... DEAD or <s>ALIVE</s>",
					responses = { "I'm going to be an upright citizen! I swear!" },
				},
				{
					text = "Sure buckaroo, sure.",
					responses = { "I SWEAR!" },
				},
			},
			responses = {
				[1] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 2)
					end,
					[2] = function(d)
						d:hideGui("Scram then.")
					end,
				},
				[2] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 3)
					end,
				},
				[3] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 4)
					end,
				},
				[4] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 5)
					end,
				},
				[5] = {
					[1] = function(d)
						d:hideGui("I'll be waiting for your bounty poster.")
					end,
				},
			},
		})
	end,
	KillerNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "Killa K",
			font = "RomanAntique",
			dialogs = {
				{
					text = "Want some quick cash?",
					responses = { "Yes", "No" },
				},
				{
					text = "I'll give you a mission, rack some bodies up and i'll give you some cash.",
					responses = { "YES!", "I'm a peacekeeper, no" },
				},
			},
			responses = {
				[1] = {
					[1] = function(d)
						QuestGUIHandler:AttemptToGiveQuest("BotKiller", npcModel)
						d:hideGui("Check your quests (M key), I might have added one.")
					end,
					[2] = function(d)
						d:hideGui("Your loss.")
					end,
				},
			},
		})
	end,

	TutorialNPC = function(npcModel: Model?, prompt: ProximityPrompt?)
		InitNPC(npcModel, prompt, {
			name = "Tutorial Master Mugi",
			font = "RomanAntique",
			dialogs = {
				{
					text = "Hey, i'm the tutorial expert Mugi-Warah AKA Mugi.<br/> How may I help?",
					responses = { "Roll", "Kick", "Charge", "Health System", "Gun System", "Thats all!" },
				},
				{
					text = "Rolling?<br/>Press E on the keyboard to initiate a roll, assuming you have enough stamina.<br/> It's a directional roll, so holding a WASD key whilst pressing it will roll to that direction.",
					responses = { "Back" },
				},
				{
					text = "Kicking?<br/>Currently can only kick barrels. Press F to kick and watch those barrels fly!<br/>I'm sure you'll find a good use for it during combat.",
					responses = { "Back" },
				},
				{
					text = "Charge?<br/> Stand still and press C to initiate a charge, hit a human, and they'll go flying, applying damage to their torso.<br/> Note if the stamina drops to 0, it will stop, so make sure to use it with sufficient stamina!<br/>Don't hit a wall though, or you'll hurt yourself.",
					responses = { "Back" },
				},
				{
					text = "Health system?<br/> Each limb has its own health bar and if its goes down enough, it will be disabled and then even lower? decapitated.<br/>Well, the right arm will be fine no matter what, so you can shoot.<br/>Theres also an overall health bar so don't sustain that much damage!",
					responses = { "Back" },
				},
				{
					text = "Gun system?<br/> Left mouse click to shoot<br/>Hold right mouse button to aim down sight<br/>R to reload which stops after it's full OR you get hit.<br/> Beware the gun can jam, so press R to unjam.",
					responses = { "Back" },
				},
			},
			responses = {
				[1] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 2)
					end,
					[2] = function(d)
						d:triggerDialog(PlayerContext.Player, 3)
					end,
					[3] = function(d)
						d:triggerDialog(PlayerContext.Player, 4)
					end,
					[4] = function(d)
						d:triggerDialog(PlayerContext.Player, 5)
					end,
					[5] = function(d)
						d:triggerDialog(PlayerContext.Player, 6)
					end,
					[6] = function(d)
						d:hideGui("Hope you learned something!")
					end,
				},
				[2] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 1)
					end,
				},
				[3] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 1)
					end,
				},
				[4] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 1)
					end,
				},
				[5] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 1)
					end,
				},
				[6] = {
					[1] = function(d)
						d:triggerDialog(PlayerContext.Player, 1)
					end,
				},
			},
		})
	end,
}
