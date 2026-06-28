local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerData = require(ServerScriptService.Server.ServerData)
local QuestData = require(ReplicatedStorage.Shared.Quests.QuestData)
local Server = require(ReplicatedStorage.Shared.Vetra.VetraNet.Server)
local QUEST_GIVER_DISTANCE_REQUIREMENT = 10
local QuestHandler = {}

function QuestHandler:ProgressQuests(player: Player)
	local activeQuests = ServerData.GetActiveQuests(player)

	if not activeQuests then
		return
	end

	for questName, data in activeQuests do
		local questBaseName = string.match(questName, "%a+")
		local questNumber = tonumber(string.match(questName, "%d+"))

		if not questBaseName or not questNumber then
			return
		end

		local questData = QuestData[questBaseName][questNumber]

		if not questData then
			warn(`Cannot progress {questName}, data doesn't exist in table`)
			return
		end

		local questType = questData.QuestType
		if not questType then
			warn(`Cannot progress {questName}, quest type missing from table`)
			return
		end

		if questType == "Kill" then
			ServerData:UpdateQuestProgress(player, questName, 1)
		end
	end
end

function QuestHandler:AddQuest(player: Player, questName: string, questGiverNPC: Model?)
	if not player or not questName or not questGiverNPC then
		return false
	end

	local character = player.Character

	if not character then
		warn("Can't add a new quest, player character is missing")
		return false
	end

	if
		(character:GetPivot().Position - questGiverNPC:GetPivot().Position).Magnitude
		> QUEST_GIVER_DISTANCE_REQUIREMENT
	then
		warn("Player too far from quest giver to add quest!")
		return false
	end

	local questData = QuestData[questName]
	local completedQuests = ServerData:GetCompletedQuests(player)
	local currentQuests = ServerData.GetActiveQuests(player)

	if not questData then
		warn(`Cannot add new quest, {questName} is not a valid quest`)
		return false
	end

	-- go thru indexed array and give next non completed quest
	for idx, _: string in questData do
		local currentQuestName = `{questName}{idx}`

		if currentQuests[currentQuestName] then
			break
		end
		if completedQuests[currentQuestName] then
			continue
		end

		ServerData:AddNewQuest(player, currentQuestName)

		return true
	end

	return false
end

local function GetQuestData(questName: string)
	local quest = string.match(questName, "%a+")
	local questNumber = tonumber(string.match(questName, "%d+"))

	local data = QuestData[quest][questNumber]
	return data
end
function QuestHandler:ClaimAward(player: Player, questName: string)
	local isActiveQuest = ServerData:GetActiveQuestData(player, questName)
	if not isActiveQuest then
		return false
	end

	-- Determine if target reached
	local progress = isActiveQuest.Progress
	local questData = GetQuestData(questName)
	if not questData then
		return false
	end
	local progressTarget = questData.QuestRequirement

	if not progressTarget then
		return false
	end

	if progress < progressTarget then
		return false
	end

	-- Target reached, award
	local rewardType: string = questData.Reward
	local rewardValue = questData.RewardValue

	if rewardType == "Cash" then
		ServerData.UpdateMoney(player, rewardValue)
	end

	self:MarkQuestComplete(player, questName)

	return true
end

function QuestHandler:MarkQuestComplete(player: Player, questName: string)
	ServerData:CompleteQuest(player, questName)
end

function QuestHandler:GetActiveQuests(player: Player)
	return ServerData.GetActiveQuests(player)
end

QuestHandler.networker = Networker.new(
	"QuestNetwork",
	QuestHandler,
	{ QuestHandler.GetActiveQuests, QuestHandler.AddQuest, QuestHandler.ClaimAward }
)

return QuestHandler
