local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

type Human = ClassTypes.Human
local ServerDigNetwork = {}

function ServerDigNetwork.SpawnDigLoot(player: Player) end

ServerDigNetwork.networker = Networker.new("TrapNetwork", ServerDigNetwork, { ServerDigNetwork.SpawnDigLoot })
return ServerDigNetwork
