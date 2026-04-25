local Vetra = require(script.Parent.Vetra)
return {
	Shrapnel = {
		ProjectileData = Vetra.BehaviorBuilder
			.new()
			:Physics()
			:MaxDistance(50)
			:MaxSpeed(200)
			:Done()
			:Bounce()
			:Max(3)
			:Done()
			:Debug()
			:Visualize(true)
			:Done()
			:Hitscan(true)
			:Build(),
	},
}
