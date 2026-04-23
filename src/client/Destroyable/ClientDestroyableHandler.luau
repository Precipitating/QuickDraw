local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local EffectsDisplayer = require(StarterPlayer.StarterPlayerScripts.Client.VisualEffectsHandler.EffectsDisplayer)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local ClientDestroyableHandler = {}

ClientDestroyableHandler.networker = Networker.new("DestroyableNetwork", ClientDestroyableHandler)

function ClientDestroyableHandler:DisplayDestroyParticle(destroyableParticleName: string, position: Vector3)
	EffectsDisplayer:DisplayDestroyableExplosion(destroyableParticleName, position)
end
function ClientDestroyableHandler:DisplaySpreadParticle(
	destroyableParticleName: string,
	duration: number,
	parent: BasePart?
)
	EffectsDisplayer:DisplaySpreadParticle(destroyableParticleName, duration, parent)
end

return ClientDestroyableHandler
