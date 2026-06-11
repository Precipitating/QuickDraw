local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientTrapNetwork = {}
ClientTrapNetwork.networker = Networker.new("TrapNetwork", ClientTrapNetwork)

return ClientTrapNetwork
