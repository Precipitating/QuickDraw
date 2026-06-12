local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ClientVetraContext =
	require(StarterPlayer.StarterPlayerScripts.Client.ClientProjectilesHandler.ClientVetraContext)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local ThrowableData = require(ReplicatedStorage.Shared.ThrowableData.ThrowableData)
local Networker = require(ReplicatedStorage.Packages.Networker).client

local ClientThrowableHandler = {}
ClientThrowableHandler.networker = Networker.new("ThrowableNetwork", ClientThrowableHandler)
local InnerJanitor = Janitor.new()
local OuterJanitor = Janitor.new()

local ThrowableRaycastParams = RaycastParams.new()
ThrowableRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
local LastThrown = 0

function ClientThrowableHandler:Throw(throwable: Tool)
	warn("throw called")
	local cameraLookVector = workspace.CurrentCamera.CFrame.LookVector
	ThrowableRaycastParams.ExcludeInstances = { throwable, PlayerContext.Character }
	local head = PlayerContext.BodyParts["Head"]
	local launchPos = head.Position + Vector3.new(0, 2, 0)
	local throwableData = ThrowableData[throwable.Name]
	local context = ClientVetraContext.Vetra.BulletContext.new({
		Origin = launchPos,
		Direction = cameraLookVector,
		Speed = throwableData.Velocity,
		RaycastParams = ThrowableRaycastParams,
	})

	local handle: Instance? = throwable:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.Transparency = 1
	end

	ClientVetraContext.Net:Fire(context, throwable.Name)

	SoundManager.Play(ThrowableData[throwable.Name].ThrowSound)
	self.networker:fire("OnClientThrow")

	if throwable and handle and handle:IsA("BasePart") then
		task.delay(ThrowableData[throwable.Name].ThrowDelay, function()
			handle.Transparency = 0
		end)
	end
end

function ClientThrowableHandler:ConnectThrowable(throwable: Tool?)
	if not throwable then
		error("Can't connect throwable, tool reference not valid!")
	end
	warn(`[CLIENT] Connecting {throwable.Name}`)

	OuterJanitor:Add(throwable.Equipped:Connect(function(_: Mouse)
		InnerJanitor:Cleanup() -- clear previous equip if any

		InnerJanitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
		end))

		InnerJanitor:Add(throwable.Activated:Connect(function()
			if PlayerContext.Humanoid.Health <= 0 then
				return
			end

			local ammo = self.networker:fetch("GetAmmo")
			if not ammo or ammo <= 0 then
				return
			end

			local now = os.clock()
			if now - LastThrown < ThrowableData[throwable.Name].ThrowDelay then
				return
			end

			LastThrown = now
			self:Throw(throwable)
		end))
	end))

	OuterJanitor:Add(throwable.Unequipped:Connect(function()
		warn(`[CLIENT] Disconnecting {throwable.Name} connection`)
		InnerJanitor:Cleanup()
	end))

	OuterJanitor:Add(throwable.Destroying:Connect(function()
		InnerJanitor:Cleanup()
		OuterJanitor:Cleanup()
	end))
end

return ClientThrowableHandler
