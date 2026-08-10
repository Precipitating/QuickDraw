local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
--  ────── Vetra Variables ──────
local EffectsDisplayer = require(script.Parent.Parent.VisualEffectsHandler.EffectsDisplayer)
local Vetra = require(ReplicatedStorage.Shared.Vetra)
local VetraNet = require(ReplicatedStorage.Shared.Vetra.VetraNet)
local VetraRegistry = require(ReplicatedStorage.Shared.VetraRegistry)
local ClientSolver = Vetra.new()
local Net = VetraNet.new(ClientSolver, VetraRegistry)
local Signals = ClientSolver:GetSignals()
local STALE_TIMEOUT = 0.15 -- seconds without an OnTravel update = considered stopped
local CHECK_INTERVAL = 0.05
local timeSinceLastCheck = 0
local lastUpdateTime = {}

local function Initialize()
	Signals.OnHit:Connect(function(context, result: RaycastResult?, _velocity)
		warn("[CLIENT] onHit called")
		if not result then
			return
		end

		EffectsDisplayer:TryDisplayProjectileMark(context, result)
	end)

	-- Detect when client cosmetics are stopped, onHit is unreliable, same with onTerminate
	RunService.Heartbeat:Connect(function(dt)
		timeSinceLastCheck += dt
		if timeSinceLastCheck < CHECK_INTERVAL then
			return
		end
		timeSinceLastCheck = 0
		for cosmetic, lastTime in lastUpdateTime do
			if os.clock() - lastTime > STALE_TIMEOUT then
				local hasLifetime = cosmetic:GetAttribute("Lifetime")
				if hasLifetime then
					task.delay(hasLifetime, function()
						cosmetic:Destroy()
						lastUpdateTime[cosmetic] = nil
					end)
				else
					cosmetic:Destroy()
					lastUpdateTime[cosmetic] = nil
				end
			end
		end
	end)

	Signals.OnTravel:Connect(function(context, position, velocity)
		lastUpdateTime[context.CosmeticBulletObject] = os.clock()
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
