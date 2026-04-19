local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ProjectileContext = require(script.Parent.ProjectileContext)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local DestroyableManager = require(ServerScriptService.Server.Managers.Destroyable.DestroyableManager)

local ProjectileEvents = {}

type Destroyable = ClassTypes.Destroyable

local function GetHumanoidFromHit(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return nil
	end

	return humanoid
end

function ProjectileEvents:GunHitPlayer(raycastResult: RaycastResult)
	local hitHumanoid = GetHumanoidFromHit(raycastResult.Instance)
	local isAccessory = raycastResult.Instance:FindFirstAncestorOfClass("Accessory")

	if not hitHumanoid then
		return false
	end

	if isAccessory then
		return false
	end

	-- hit body part
	GunSignals.PlayerHit:Fire(raycastResult, hitHumanoid, self.Damage, self.PlayerRef)
	print(`{raycastResult.Instance.Name} hit!`)
	return true
end

function ProjectileEvents:GunHitDestroyable(raycastResult: RaycastResult)
	local instance = raycastResult.Instance
	local destroyableClass: Destroyable = DestroyableManager.Destroyables[instance]
	if not destroyableClass then
		return
	end

	destroyableClass:Damage(self.Damage, self.PlayerRef)

	return true
end

-- This should be executed last, as every other option should be exhausted before deciding we've hit
-- the environment.
function ProjectileEvents:GunHitEnvironment(raycastResult: RaycastResult)
	-- hit environment
	local hitPos = CFrame.lookAt(raycastResult.Position, raycastResult.Position + raycastResult.Normal)
	GunSignals.DisplayBulletHole:Fire(hitPos)
end

function ProjectileEvents.Initialize()
	ProjectileContext.VetraSignals.OnHit:Connect(function(context, result, velocity)
		print("OnHit fired") -- does this print at all?
		print("UserData:", context.UserData)
		print("Result:", result)
		if context.UserData.Type == "Gun" then
			local hitPlayer = ProjectileEvents:GunHitPlayer(result)
			if hitPlayer then
				return
			end

			local hitDestroyable = ProjectileEvents:GunHitEnvironment(result)
			if hitDestroyable then
				return
			end

			ProjectileEvents:GunHitEnvironment(result)
		end
	end)
end

return ProjectileEvents
