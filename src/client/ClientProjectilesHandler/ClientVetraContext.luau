local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
--  ────── Vetra Variables ──────
local EffectsDisplayer = require(StarterPlayer.StarterPlayerScripts.Client.VisualEffectsHandler.EffectsDisplayer)
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)

local ClientSolver = Vetra.new()
local Net = VetraNet.new(ClientSolver, VetraRegistry)

local function TryDisplayProjectileMark(context, result: RaycastResult?)
	if not result then
		return
	end

	if result.Instance.Parent and result.Instance.Parent:IsA("Tool") then
		warn("hit frame")
		return
	end

	if context.CosmeticBulletObject then
		local canDisplayBulletHole = result.Instance
			and not CollectionService:HasTag(result.Instance, "Destroyable")
			and not CollectionService:HasTag(result.Instance, "Player")
			and not CollectionService:HasTag(result.Instance.Parent, "NPC")
		if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") and canDisplayBulletHole then
			EffectsDisplayer:DisplayProjectileMark("Bullet", result)
		end
	end
end

local function Initialize()
	ClientSolver:GetSignals().OnHit:Connect(function(context, result: RaycastResult?, _velocity)
		warn("[CLIENT] onHit called")
		if not result then
			return
		end
		TryDisplayProjectileMark(context, result)
	end)

	ClientSolver:GetSignals().OnPierce:Connect(function(context, result: RaycastResult?, _velocity, pierceCount)
		if not result then
			return
		end
		warn("[CLIENT] onPierce called")
		TryDisplayProjectileMark(context, result)
	end)
end

Initialize()
return {
	Net = Net,
	ClientSolver = ClientSolver,
	Registry = VetraRegistry,
	Vetra = Vetra,
}
