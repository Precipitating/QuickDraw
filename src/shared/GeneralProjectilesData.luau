local Vetra = require(script.Parent.Vetra)
return {
	Shrapnel = {
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(70)
			:MaxSpeed(200)
			:Done()
			:Bounce()
			:Max(3)
			:Done()
			:Debug()
			:Visualize(false)
			:Done()
			:Hitscan(true)
			:Build(),
	},
}
