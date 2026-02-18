local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GunConfig = require(script.Parent.GunConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local PoolHandler = require(StarterPlayer.StarterPlayerScripts.Client.Pools.PoolHandler)
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
type Networker = NetworkClient

local ClientGunHandler = {}
ClientGunHandler.janitor = Janitor.new()
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)
local CurrentCamera = workspace.CurrentCamera
local ADSTween = nil
local HoldingRMB = false
local GunEquipConn = nil
local GunDisconnectConn = nil

function ClientGunHandler:ActivateMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end
	local muzzleFolder = gunTool:WaitForChild("MuzzleFlash"):WaitForChild("Attachment")

	if not muzzleFolder then
		warn("[ ClientGunHandler:ActivateMuzzleFlash] muzzleFolder invalid!")
		return
	end

	for _, effect in pairs(muzzleFolder:GetChildren()) do
		if not effect:IsA("ParticleEmitter") then
			continue
		end

		effect:Emit(1)
	end

	self:ApplyPistolRecoil(gunTool)
end

function ClientGunHandler:DisplayBulletHole(cframeTarget: CFrame?)
	if not cframeTarget then
		warn("Client received an invalid cframeTarget when showing a bullet hole!")
		return
	end
	local availableBulletHole: Part = PoolHandler.BulletPool:Acquire()
	availableBulletHole:PivotTo(cframeTarget)
end

function ClientGunHandler:ApplyPistolRecoil(gunTool: Tool)
	local handle: Part? = gunTool:WaitForChild("Handle") :: Part
	local shootPoint: Attachment? = gunTool:WaitForChild("ShootPoint") :: Attachment
	local gunHolderModel: Model? = gunTool:FindFirstAncestorOfClass("Model")
	assert(gunHolderModel, "Cannot apply recoil locally, can't get person's model")

	local rightArm: MeshPart = gunHolderModel:WaitForChild("RightUpperArm", 10) :: MeshPart

	if not handle then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get Handle`)
		return
	end
	if not shootPoint then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get shootPoint`)
		return
	end
	if not rightArm then
		warn(`[ClientGunHandler:ApplyPistolRecoil()] failed to get right upper arm`)
		return
	end

	handle:ApplyImpulseAtPosition(Vector3.new(0, 1, 0) * 10, shootPoint.WorldPosition)
	rightArm:ApplyImpulse(rightArm.AssemblyMass * Vector3.new(0, 1, 0) * 100)
end
local function StopCurrentTween()
	if ADSTween then
		ADSTween:Cancel()
		ADSTween = nil
	end
end

local function CancelADS()
	StopCurrentTween()

	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	PlayerContext.Humanoid.AutoRotate = true

	ADSTween = TweenService:Create(
		PlayerContext.Humanoid,
		TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CameraOffset = Vector3.new(0, 0, 0) }
	)

	ADSTween:Play()
end

local function ADSTweenZoom(gunTool: Tool)
	StopCurrentTween()
	PlayerContext.Humanoid.AutoRotate = false
	UserInputService.MouseIconEnabled = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	CurrentCamera.CameraSubject = PlayerContext.Character:WaitForChild("RightUpperArm", 10)

	ADSTween = TweenService:Create(
		PlayerContext.Humanoid,
		TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CameraOffset = Vector3.new(2.4, -3, -20) }
	)

	ADSTween:Play()

	local rightShoulder: AnimationConstraint =
		PlayerContext.Character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
	ClientGunHandler.janitor:Add(
		RunService.RenderStepped:Connect(function()
			local camLookAt = CurrentCamera.CFrame.LookVector

			-- rotate around
			local rotateLook = Vector3.new(camLookAt.X, 0, camLookAt.Z).Unit
			local hrp = PlayerContext.HRP
			hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + rotateLook)

			-- tilt up/down
			local pitch = math.asin(camLookAt.Y)
			pitch = math.clamp(pitch, -math.rad(60), math.rad(60))
			rightShoulder.Transform = CFrame.Angles(pitch, 0, 0)
		end),
		"Disconnect",
		"Rotate"
	)
end

function ClientGunHandler:ConnectGun(gun: Tool?)
	print("connecting gun")
	if not gun then
		error("Can't connect guns, tool reference not valid!")
	end

	if GunEquipConn and GunDisconnectConn then
		GunEquipConn:Disconnect()
		GunDisconnectConn:Disconnect()
	end

	GunEquipConn = gun.Equipped:Connect(function(mouse: Mouse)
		self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = true
				ADSTweenZoom(gun)
			end
		end))

		self.janitor:Add(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = false
				self.janitor:Remove("Rotate")
				CancelADS()
			end
		end))

		self.janitor:Add(gun.Activated:Connect(function()
			if PlayerContext.Humanoid.health <= 0 then
				return
			end
			local shot = GunNetwork:fetch("ShootGun", PlayerContext.Humanoid)

			if shot then
				self:ActivateMuzzleFlash(gun)
				SoundManager.Play("RevolverShot", {
					Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
				})
			else
				SoundManager.Play("RevolverClick", {
					Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
				})
			end
		end))
	end)

	GunDisconnectConn = gun.Unequipped:Connect(function()
		print("Disconnecting gun connections!")
		HoldingRMB = false
		CurrentCamera.CameraSubject = PlayerContext.Humanoid
		self:DisconnectGun()
	end)
end

function ClientGunHandler:DisconnectGun()
	print("Gun disconnected!")
	CancelADS()
	self.janitor:Cleanup()
end

function ClientGunHandler:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	if not position then
		error("Can't apply blood to position, POSITION is nil on DisplayBloodHit")
	end

	if not normal then
		error("Can't apply blood to position, normal is nil on DisplayBloodHit")
	end

	local hitPos = CFrame.lookAt(position, position + normal)

	local availableBlood: Part = PoolHandler.BloodPool:Acquire()

	if not availableBlood then
		error("Can't find available blood from its pool, does it exist?")
	end

	availableBlood:PivotTo(hitPos)

	-- enable blood and disable after a short time
	for _, particle in ipairs(availableBlood:GetChildren()) do
		particle:Emit(1)
	end
end

return GunNetwork
