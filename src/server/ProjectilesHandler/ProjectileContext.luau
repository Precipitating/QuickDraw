local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local BulletContext = require(ReplicatedStorage.Shared.Vetra.Core.BulletContext)
local Solver = Vetra.new()
local VetraSignals = Solver:GetSignals()

return {
	Solver = Solver,
	BulletContext = BulletContext,
	VetraSignals = VetraSignals,
}
