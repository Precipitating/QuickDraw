local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)
local BulletContext = require(ReplicatedStorage.Shared.Vetra.Core.BulletContext)
local Enums = require(ReplicatedStorage.Shared.Vetra.VetraNet.Types.Enums)

local ServerSolver = Vetra.newParallel()
local Net = VetraNet.new(ServerSolver, VetraRegistry, {
	Mode = Enums.NetworkMode.SharedAuthority,
	MaxOriginTolerance = 20,
	MaxConcurrentPerPlayer = 50,
	TokensPerSecond = 40,
	BurstLimit = 40,
	ReplicateState = true,
})
local VetraSignals = ServerSolver:GetSignals()

return {
	Net = Net,
	Solver = ServerSolver,
	BulletContext = BulletContext,
	VetraSignals = VetraSignals,
}
