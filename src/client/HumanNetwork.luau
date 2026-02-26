local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local HumanNetwork = {}
HumanNetwork.networker = Networker.new("HumanNetwork", HumanNetwork)
function HumanNetwork:IsLegless(player: Player)
	return self.networker:fetch("IsLegless", player)
end
function HumanNetwork:RagdollClient()
	PlayerContext.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
end
return HumanNetwork
