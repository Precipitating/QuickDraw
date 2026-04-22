local CollectionService = game:GetService("CollectionService")
local ClientVetraContext = require(script.Parent.ClientVetraContext)
local ClientProjectileEvents = {}

function ClientProjectileEvents:Initialize()
	local signals = ClientVetraContext.ClientSolver:GetSignals()

	signals.OnHit:Connect(function(context, result, velocity)
		if not result then
			return
		end
		warn("Client received OnHit")

		if context.CosmeticBulletObject and CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
			local hitPos = CFrame.lookAt(result.Position, result.Position + result.Normal)
			self:DisplayBulletHole(hitPos)
		end
	end)

	signals.OnPierce:Connect(function(context, result: RaycastResult, velocity: Vector3, pierceCount: number)
		if not result then
			return
		end
		warn("Client received OnPierce")
		if context.CosmeticBulletObject and CollectionService:HasTag(context.CosmeticBulletObject, "Bullet") then
			local hitPos = CFrame.lookAt(result.Position, result.Position + result.Normal)
			self:DisplayBulletHole(hitPos)
		end
	end)
end

return ClientProjectileEvents
