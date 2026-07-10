local ReplicatedStorage = game:GetService("ReplicatedStorage")
--  ────── Vetra Variables ──────
local EffectsDisplayer = require(script.Parent.Parent.VisualEffectsHandler.EffectsDisplayer)
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)
local ClientSolver = Vetra.new()
local Net = VetraNet.new(ClientSolver, VetraRegistry)
local Signals = ClientSolver:GetSignals()

local function Initialize()
	Signals.OnHit:Connect(function(context, result: RaycastResult?, _velocity)
		warn("[CLIENT] onHit called")
		if not result then
			return
		end
		EffectsDisplayer:TryDisplayProjectileMark(context, result)
	end)

	Signals.OnPierce:Connect(function(context, result: RaycastResult?, _velocity, pierceCount)
		if not result then
			return
		end
		warn("[CLIENT] onPierce called")
		EffectsDisplayer:TryDisplayProjectileMark(context, result)
	end)
end

Initialize()
return {
	Net = Net,
	ClientSolver = ClientSolver,
	Registry = VetraRegistry,
	Vetra = Vetra,
}
