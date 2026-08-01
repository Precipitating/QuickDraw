local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
require(script.Parent.Parent.GUI.HumanLimbGUIHandler)
require(script.Parent.Parent.GUI.QuestGUIHandler)
local ZoneHandler = require(script.Parent.Parent.ZoneHandler)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local Inputs = require(script.Parent.Parent.Parent.Client.ClientInputs.Inputs)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local MainMenuAssets = ReplicatedStorage.Shared.Templates.MainMenu
local GUIs = ReplicatedStorage.Shared.GUI

local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local ClientInputs = require(script.Parent.Parent.ClientInputs.ProximityPromptHandler)
local NPCHandler = require(script.Parent.Parent.NPCs.NPCHandler)
local ClientData = require(script.Parent.Parent.ClientData)
local ClientUtility = require(script.Parent.Parent.Utility.ClientUtility)
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)

local Player = Players.LocalPlayer

local MainMenuScreen = {}

local MainAnim = Instance.new("Animation")
MainAnim.AnimationId = "rbxassetid://133915879091915"
local TrollAnim = Instance.new("Animation")
TrollAnim.AnimationId = "rbxassetid://126558908667415"

local function PlayRandomWeightedAnimation(animator: Animator)
	local track = animator:LoadAnimation(RandomModule.WeightedRandom({
		{ value = MainAnim, weight = 90 },
		{ value = TrollAnim, weight = 10 },
	}))

	track:Play()

	track.DidLoop:Once(function()
		track:Stop()
		track:Destroy()
		PlayRandomWeightedAnimation(animator)
	end)
end

local function LoadStartGUIS()
	local currencyGUI = Utility.GetInstance(GUIs, true, "CurrencyGUI")
	if not currencyGUI then
		warn("Missing currency GUI")
		return
	end
	currencyGUI = currencyGUI:Clone()
	currencyGUI.Parent = Player:WaitForChild("PlayerGui")
end

local function Tween(btn, size)
	TS:Create(btn, TweenInfo.new(0.2), { Size = size }):Play()
end

local function LoadMenuGUI()
	local gui = GUIs.MainMenuGUI:Clone()
	local startButton: TextButton = Utility.GetInstance(gui, true, "StartButton")
	local originalSize = startButton.Size
	if not startButton then
		return
	end

	startButton.Activated:Once(function()
		HumanNetwork:FinishedLoadingGame()
		SoundManager.PlayKeyed("Voiceline", "LetsGo")
		Player.CharacterAdded:Wait()
		LoadStartGUIS()
		ClientData.Initialize()
		PlayerContext:Initialize()
		ClientInputs.Initialize()
		Inputs:Initialize()
		NPCHandler:Initialize()
		gui:Destroy()
		ClientUtility.ToggleControls(true)
		ZoneHandler:Initialize()
		NPCHandler:InitializeNPCDialogue()
		warn("DONE")
	end)

	startButton.MouseEnter:Connect(function()
		Tween(startButton, UDim2.fromScale(originalSize.X.Scale * 1.1, originalSize.Y.Scale * 1.1))
	end)

	startButton.MouseLeave:Connect(function()
		Tween(startButton, originalSize)
	end)

	gui.Parent = Player:WaitForChild("PlayerGui")
end

function MainMenuScreen:InitializeShowdownScene()
	local scene: Model = Utility.GetInstance(MainMenuAssets, true, "MainMenuScene"):Clone()
	local playerModel: Model = Utility.GetInstance(MainMenuAssets, true, "PlayerMainMenu"):Clone()
	local playerHumanoid: Humanoid = Utility.GetInstance(playerModel, true, "Humanoid")

	local cowboyModel: Model = Utility.GetInstance(MainMenuAssets, true, "CowboyMainMenu"):Clone()
	local cowboyHumanoid: Humanoid = Utility.GetInstance(cowboyModel, true, "Humanoid")

	if not scene or not playerModel or not playerHumanoid or not cowboyModel or not cowboyHumanoid then
		return
	end

	scene.Parent = workspace
	playerModel.Parent = scene
	cowboyModel.Parent = scene

	local cameraPos = Utility.GetInstance(scene, true, "CameraPos")

	if not cameraPos then
		warn("Missing camera position")
		return
	end

	local ok, result = pcall(function()
		local playerClone = Players:CreateHumanoidModelFromUserIdAsync(Players.LocalPlayer.UserId)
		local humanoid = playerClone:WaitForChild("Humanoid")
		local description = humanoid:GetAppliedDescription()
		playerHumanoid:ApplyDescriptionAsync(description)
		playerClone:Destroy()
	end)

	if not ok then
		warn("Failed to apply appearance:", result)
	end
	local playerAnimator: Animator = Utility.GetInstance(playerHumanoid, true, "Animator")
	local cowboyAnimator: Animator = Utility.GetInstance(cowboyHumanoid, true, "Animator")

	local track = playerAnimator:LoadAnimation(MainAnim)
	track:Play()
	PlayRandomWeightedAnimation(cowboyAnimator)

	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	workspace.CurrentCamera:PivotTo(cameraPos.CFrame)

	LoadMenuGUI()
end

function MainMenuScreen:OpenMainMenu()
	self:InitializeShowdownScene()
end

return MainMenuScreen
