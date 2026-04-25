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

local function GetHoleCFrame(position: Vector3, normal: Vector3): CFrame
	local up = Vector3.new(0, 1, 0)
	-- if normal is nearly parallel to world up, use a different up vector
	if math.abs(normal:Dot(up)) > 0.99 then
		up = Vector3.new(0, 0, 1)
	end
	local right = normal:Cross(up).Unit
	local adjustedUp = right:Cross(normal).Unit
	return CFrame.fromMatrix(position + normal * 0.01, right, adjustedUp, -normal)
end
local function TryDisplayBulletHoleOnSurface(context, result: RaycastResult?)
	if not result then
		return
	end

	if context.CosmeticBulletObject then
		local canDisplayBulletHole = result.Instance
			and not CollectionService:HasTag(result.Instance, "Destroyable")
			and not CollectionService:HasTag(result.Instance, "Player")
			and not CollectionService:HasTag(result.Instance.Parent, "NPC")
		if CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") and canDisplayBulletHole then
			local hitPos = GetHoleCFrame(result.Position, result.Normal)
			EffectsDisplayer:DisplayBulletHole(hitPos)
		end
	end
end

local function Initialize()
	ClientSolver:GetSignals().OnHit:Connect(function(context, result: RaycastResult?, _velocity)
		warn("[CLIENT] onHit called")
		if not result then
			return
		end
		TryDisplayBulletHoleOnSurface(context, result)
	end)

	ClientSolver:GetSignals().OnPierce:Connect(function(context, result: RaycastResult?, _velocity, pierceCount)
		if not result then
			return
		end
		warn("[CLIENT] onPierce called")
		TryDisplayBulletHoleOnSurface(context, result)
	end)
end

Initialize()
return {
	Net = Net,
	ClientSolver = ClientSolver,
	Registry = VetraRegistry,
	Vetra = Vetra,
}
