local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(script.Parent.Vetra)

return {
	Shrapnel = {
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(100)
			:MaxSpeed(200)
			:Done()
			:Bounce()
			:Max(3)
			:Done()
			:Cosmetic()
			:Template(ReplicatedStorage.Shared.Templates.ProjectileCosmetics.PistolBulletCosmetic)
			:Container(workspace.ProjectilesFolder)
			:Done()
			:Debug()
			:Visualize(false)
			:Done()
			:Hitscan(true)
			:Build(),
	},
}
