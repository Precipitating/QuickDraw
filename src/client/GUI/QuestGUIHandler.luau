local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CrosshairHandler = require(script.Parent.CrosshairHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local QuestData = require(ReplicatedStorage.Shared.Quests.QuestData)
local QuestButtonTemplate = ReplicatedStorage.Shared.Quests.QuestButton

local Networker = require(ReplicatedStorage.Packages.Networker).client

local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

local QuestGUIHandler = {}
QuestGUIHandler.janitor = Janitor.new()
QuestGUIHandler.networker = Networker.new("QuestNetwork", QuestGUIHandler)

function QuestGUIHandler:PopulateWithObtainedQuests(parent, questDataFrame)
	if not parent or not questDataFrame then
		warn(`[PopulateWithObtainedQuests] Missing arguments validity`)
		return
	end

	local result = self.networker:fetch("GetActiveQuests")

	if not result then
		return
	end

	for _, quest: { Name: string, Progress: number } in result do
		local questData = QuestData[quest.Name]

		if not questData then
			continue
		end

		local btn: TextButton = QuestButtonTemplate:Clone()
		btn.Text = questData.Title
		self.janitor:Add(btn, "Destroy")
		self.janitor:Add(btn.Activated:Connect(function()
			questDataFrame.Title.Text = questData.Title
			questDataFrame.Description.Text = questData.Description
			questDataFrame.ProgressBar.Size = UDim2.fromScale(quest.Progress / questData.QuestRequirement, 1)
			questDataFrame.Visible = true
			self.janitor:Add(questDataFrame.ClaimReward.Activated:Once(function()
				local awardClaimed = self.networker:fetch("ClaimAward", quest.Name)

				if awardClaimed then
					SoundManager.PlayKeyed("SFX", "QuestComplete")
					questDataFrame.ClaimReward.Visible = false
				end
			end))
		end))

		btn.Parent = parent
	end
end

function QuestGUIHandler:ConnectQuestGUI(gui: ScreenGui)
	if gui.Enabled then
		self:Disconnect(gui)
		return
	end
	local questBG: TextButton = Utility.GetInstance(gui, true, "BG")
	local questData: Frame = Utility.GetInstance(questBG, true, "QuestData")
	local questTitle: TextLabel = Utility.GetInstance(questBG, true, "Title")
	local questDescription: TextLabel = Utility.GetInstance(questData, true, "Description")
	local questClaimButton: TextButton = Utility.GetInstance(questData, true, "ClaimReward")
	local questProgressCanvas: CanvasGroup = Utility.GetInstance(questData, true, "ProgressBar")
	local questProgressFrame: Frame = Utility.GetInstance(questProgressCanvas, true, "Frame")
	local exitButton: TextButton = Utility.GetInstance(gui, true, "ExitButton")
	local scrollingFrame: ScrollingFrame = Utility.GetInstance(questBG, true, "ScrollingFrame")

	assert(questBG, "Missing questBG from QuestGUI")
	assert(questData, "Missing questData from QuestGUI")
	assert(questTitle, "Missing questTitle from QuestGUI")
	assert(questDescription, "Missing questDescription from QuestGUI")
	assert(questClaimButton, "Missing questClaimButton from QuestGUI")
	assert(questProgressCanvas, "Missing questProgressCanvas from QuestGUI")
	assert(questProgressFrame, "Missing questProgressFrame from QuestGUI")
	assert(exitButton, "Missing exitButton from QuestGUI")

	PlayerContext.ApplyMouseLock(false)
	CrosshairHandler:ToggleCrosshairVisibility(true)

	self:PopulateWithObtainedQuests(scrollingFrame, questData)
	gui.Enabled = true
	exitButton.Activated:Once(function()
		self:Disconnect(gui)
	end)
end

function QuestGUIHandler:Disconnect(gui)
	gui.Enabled = false
	PlayerContext.ApplyMouseLock(true)
	CrosshairHandler:ToggleCrosshairVisibility(false)
	self.janitor:Cleanup()
end

return QuestGUIHandler
