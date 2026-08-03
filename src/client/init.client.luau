local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightweightNpcsClientModule = require(ReplicatedFirst.LightweightNpcsClient.Code.LightweightNpcsClientModule)
local MainMenuScreen = require(script.MainMenu.MainMenuScreen)
local ClientUtility = require(script.Utility.ClientUtility)
local CoreGUIHandler = require(script.Utility.CoreGUIHandler)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
require(script.VisualEffectsHandler.EffectsDisplayer)
require(script.Animations.AnimationSignalsLogic)
require(script.Sound.ClientSoundHandler)
require(script.Gun.ClientGunHandler)
require(script.Throwable.ClientThrowableHandler)
require(script.Trap.ClientTrapHandler)
require(script.Train.TrainHandler):Initialize()
require(script.GUI.PopupHandler)
require(script.OnSeatedClientHandler)

local function WaitForPlayerLoad()
	ClientUtility.ToggleControls(false)
	CoreGUIHandler.ToggleBackpackVisibility(false)
	SoundManager.Init()
	SoundManager.PlayKeyed("Music", "MainTheme", { FadeIn = 0.5 })

	-- ensure loading screen finished loading
	repeat
		task.wait()
	until CollectionService:HasTag(Players.LocalPlayer, "ClientLoaded")
	CollectionService:RemoveTag(Players.LocalPlayer, "ClientLoaded")

	MainMenuScreen:OpenMainMenu()
end
WaitForPlayerLoad()
