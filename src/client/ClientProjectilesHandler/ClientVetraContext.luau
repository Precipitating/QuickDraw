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

local NoProjectileDecalList = { "Destroyable", "Player", "NPC", "Barrier" }

local function CanDisplayBulletHole(instance: Instance)
	for _, tag in NoProjectileDecalList do
		if CollectionService:HasTag(instance.Parent, tag) then
			return false
		end
		if CollectionService:HasTag(instance, tag) then
			return false
		end
	end

	return true
end
local function TryDisplayProjectileMark(context, result: RaycastResult?)
	if not result then
		return
	end

	if result.Instance.Parent and result.Instance.Parent:IsA("Tool") then
		warn("hit frame")
		return
	end

	if context.CosmeticBulletObject then
		local canDisplayBulletHole = result.Instance and CanDisplayBulletHole(result.Instance)

		if not canDisplayBulletHole then
			return
		end
		if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
			EffectsDisplayer:DisplayProjectileMark("Bullet", result)
		elseif CollectionService:HasTag(context.CosmeticBulletObject, "CannonBall") then
			EffectsDisplayer:DisplayProjectileMark("CannonBall", result)
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
