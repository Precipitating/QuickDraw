local ReplicatedStorage = game:GetService("ReplicatedStorage")
--  ────── Vetra Variables ──────
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)
local ClientSolver = Vetra.new()
local Net = VetraNet.new(ClientSolver, VetraRegistry)

return {
	Net = Net,
	ClientSolver = ClientSolver,
	Registry = VetraRegistry,
	Vetra = Vetra,
}
