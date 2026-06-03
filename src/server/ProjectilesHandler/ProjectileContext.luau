local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)
local BulletContext = require(ReplicatedStorage.Shared.Vetra.Core.BulletContext)
local Enums = require(ReplicatedStorage.Shared.Vetra.VetraNet.Types.Enums)

local Solver = Vetra.new()
local Net = VetraNet.new(Solver, VetraRegistry, {
	Mode = Enums.NetworkMode.SharedAuthority,
	MaxOriginTolerance = 20,
	MaxConcurrentPerPlayer = 50,
	TokensPerSecond = 15,
	BurstLimit = 15,
	ReplicateState = true,
})
local VetraSignals = Solver:GetSignals()

return {
	Net = Net,
	Solver = Solver,
	BulletContext = BulletContext,
	VetraSignals = VetraSignals,
}
