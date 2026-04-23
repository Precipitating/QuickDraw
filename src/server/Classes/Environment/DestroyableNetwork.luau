local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker).server
local DestroyableNetwork = {}

function DestroyableNetwork:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
	self.networker:fireAll("DisplayDestroyParticle", destroyableParticleName, position)
end
function DestroyableNetwork:DisplaySpreadParticle(destroyableParticleName: string, duration: number, parent: BasePart?)
	self.networker:fireAll("DisplaySpreadParticle", destroyableParticleName, duration, parent)
end
DestroyableNetwork.networker = Networker.new("DestroyableNetwork", DestroyableNetwork)
return DestroyableNetwork
