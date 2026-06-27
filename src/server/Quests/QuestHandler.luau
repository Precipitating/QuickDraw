local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local ServerData = require(ServerScriptService.Server.ServerData)
local QuestData = require(ReplicatedStorage.Shared.Quests.QuestData)

local QuestHandler = {}

function QuestHandler:AddQuest(player: Player, questName: string) end

function QuestHandler:MarkQuestComplete(player: Player, questName: string) end

function QuestHandler:RemoveQuest(player: Player, questName: string) end

function QuestHandler:GetActiveQuests(player: Player)
	return ServerData.GetActiveQuests(player)
end

QuestHandler.networker = Networker.new("QuestNetwork", QuestHandler, { QuestHandler.GetActiveQuests })

return QuestHandler
