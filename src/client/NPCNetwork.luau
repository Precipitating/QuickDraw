-- Remotes from server to handle Human NPC synchronization
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).client

local NPCNetwork = {}

NPCNetwork.networker = Networker.new("NPCNetwork")

function NPCNetwork:RagdollNPC(id: number, time: number) end

function NPCNetwork:KillNPC(id: number) end

function NPCNetwork:EquipGun(id: number, gunName: string) end

function NPCNetwork:ShootGun(id: number, gunName: string) end

return NPCNetwork
