local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GunConfig = require(script.Parent.GunConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PoolHandler = require(StarterPlayer.StarterPlayerScripts.Client.Pools.PoolHandler)
local PlayerContext = require(StarterPlayer.StarterPlayerScripts.Client.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local FastCastRedux = require(ReplicatedStorage.Packages.FastCastRedux)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local GunDataTypes = require(ReplicatedStorage.Shared.GunData.GunDataTypes)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

type Networker = NetworkClient
type GunData = GunDataTypes.GunData

local ClientGunHandler = {}
ClientGunHandler.janitor = Janitor.new()
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)
local CurrentCamera = workspace.CurrentCamera
local ADSTween = nil
local HoldingRMB = false
local GunEquipConn = nil
local GunDisconnectConn = nil
local LastCrosshairHit = 0

-- for camera recoil
local RecoilSpring = Ripple.createSpring(0, {
	dampingRatio = 0.9,
	frequency = 7.5,
	start = true,
})

local FastCast = FastCastRedux.new()
local BulletVelocity = 900
local ProjectileData = FastCast.newBehavior()
ProjectileData.RaycastParams = RaycastParams.new()
ProjectileData.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
ProjectileData.RaycastParams.FilterDescendantsInstances = {}
ProjectileData.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
ProjectileData.MaxDistance = 250
ProjectileData.AutoIgnoreContainer = true

function ClientGunHandler:ActivateMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end
	local muzzleFolder = Utility.GetInstance(gunTool, true, "MuzzleFlash", "Attachment")

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
end

function ClientGunHandler:DisplayBulletHole(cframeTarget: CFrame?)
	if not cframeTarget then
		warn("Client received an invalid cframeTarget when showing a bullet hole!")
		return
	end
	local availableBulletHole: Part = PoolHandler.BulletPool:Acquire()
	availableBulletHole:PivotTo(cframeTarget)
end

function ClientGunHandler:ApplyGunRecoil(gunTool: Tool)
	local handle: Part? = gunTool:WaitForChild("Handle") :: Part
	local shootPoint: Attachment? = gunTool:WaitForChild("ShootPoint") :: Attachment
	local gunHolderModel: Model? = gunTool:FindFirstAncestorOfClass("Model")
	assert(gunHolderModel, "Cannot apply recoil locally, can't get person's model")

	local rightArm: MeshPart = gunHolderModel:WaitForChild("RightUpperArm", 10) :: MeshPart

	if not handle then
		warn(`[ClientGunHandler:ApplyGunRecoil()] failed to get Handle`)
		return
	end
	if not shootPoint then
		warn(`[ClientGunHandler:ApplyGunRecoil()] failed to get shootPoint`)
		return
	end
	if not rightArm then
		warn(`[ClientGunHandler:ApplyGunRecoil()] failed to get right upper arm`)
		return
	end

	handle:ApplyImpulseAtPosition(Vector3.new(0, 1, 0) * GunData[gunTool.Name].GunRecoil, shootPoint.WorldPosition)
	rightArm:ApplyImpulse(rightArm.AssemblyMass * Vector3.new(0, 1, 0) * GunData[gunTool.Name].ArmRecoil)

	-- also make camera flick up via springs
	RecoilSpring:setGoal(GunData[gunTool.Name].CameraRecoil)
end
local function StopCurrentTween()
	if ADSTween then
		ADSTween:Cancel()
		ADSTween = nil
	end
end
local function ADSTransparency(on: boolean)
	for _, part in pairs(PlayerContext.Character:GetDescendants()) do
		if not part:IsA("MeshPart") then
			continue
		end

		if part.Parent:IsA("Tool") then
			continue
		end

		if on then
			part.Transparency = 1
		else
			part.Transparency = 0
		end
	end
end

local function GetCrosshair()
	local crosshairPart = Utility.GetInstance(workspace, true, "Crosshair")
	local crosshairBillboard = Utility.GetInstance(crosshairPart, true, "CrosshairBB")
	local crosshairImage = Utility.GetInstance(crosshairBillboard, true, "ImageLabel")
	return crosshairPart, crosshairBillboard, crosshairImage
end

local function CancelADS()
	StopCurrentTween()

	local _: Part, crosshairBB: BillboardGui, _: ImageLabel = GetCrosshair()
	crosshairBB.Enabled = false

	CurrentCamera.CameraSubject = PlayerContext.Humanoid
	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MAX_ZOOM_DIST
	ADSTransparency(false)
	UserInputService.MouseIconEnabled = false
	ADSTween = TweenService:Create(
		CurrentCamera,
		TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ FieldOfView = GunConfig.NORMAL_FOV }
	)

	ADSTween:Play()
end

local function CastBarrelRay(shootPoint: Attachment)
	if not shootPoint then
		warn("Casting ray failed, shootpoint nil")
		return
	end
	local origin: Vector3 = shootPoint.WorldPosition
	local direction: Vector3 = shootPoint.WorldCFrame.LookVector

	FastCast:Fire(origin, direction, BulletVelocity, ProjectileData)
end

local function AimAndDisplayCrosshair(gunTool: Tool)
	local character = PlayerContext.Character

	local rightShoulder = Utility.GetInstance(character, true, "RightUpperArm", "RightShoulder")

	local rightShoulderAttachment: Attachment = rightShoulder.Attachment0

	local rightShoulderOriginalCF: CFrame = rightShoulderAttachment.CFrame

	-- crosshair
	local crosshairPart: Part, crosshairBB: BillboardGui, _: ImageLabel = GetCrosshair()
	local shootPoint = gunTool:WaitForChild("ShootPoint", 10)
	local BIND_NAME = "ADS_RotateAndTilt"
	ProjectileData.RaycastParams.FilterDescendantsInstances =
		{ PlayerContext.Character, gunTool:FindFirstChild("Frame"), crosshairPart }

	-----------------------------------------------------------------------
	-- BindToRenderStep at the very end so nothing overwrites us
	-----------------------------------------------------------------------
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, function(dt)
		-- ── Pitch: tilt upper body to follow camera vertically ──
		local lookVector = CurrentCamera.CFrame.LookVector
		local pitch = math.asin(math.clamp(lookVector.Y, -1, 1))
		local shoulderPitch = math.clamp(pitch, -math.rad(80), math.rad(90))

		rightShoulderAttachment.CFrame = rightShoulderOriginalCF * CFrame.Angles(shoulderPitch, 0, 0)

		CastBarrelRay(shootPoint)
		if crosshairBB.Enabled then
			local currentTime = os.clock()
			if (currentTime - LastCrosshairHit) > 0.01 then
				crosshairBB.Enabled = false
			end
		end
	end)

	--recoil
	ClientGunHandler.janitor:Add(RecoilSpring:onChange(function(currentVal, dt)
		local offset = CFrame.Angles(math.rad(currentVal), 0, 0)
		CurrentCamera.CFrame *= offset
	end))

	ClientGunHandler.janitor:Add(RecoilSpring:onComplete(function()
		RecoilSpring:setGoal(-GunData[gunTool.Name].CameraRecoil)
	end))

	-- setting crosshair via raycast result
	ClientGunHandler.janitor:Add(
		FastCast.RayHit:Connect(function(_, rayHitResult: RaycastResult, _)
			if rayHitResult then
				crosshairBB.Enabled = true
				crosshairPart.Position = rayHitResult.Position
				LastCrosshairHit = os.clock()
			end
		end),
		"Disconnect",
		"RayHit"
	)

	-----------------------------------------------------------------------
	-- Cleanup: unbind + restore the attachment to its original pose
	-----------------------------------------------------------------------
	ClientGunHandler.janitor:Add(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
		rightShoulderAttachment.CFrame = rightShoulderOriginalCF
		crosshairBB.Enabled = false
	end, true, "Rotate")
end
local function ADSTweenZoom(gunTool: Tool)
	StopCurrentTween()

	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MIN_ZOOM_DIST
	CurrentCamera.CameraSubject = gunTool:FindFirstChild("AimPos")
	ADSTransparency(true)
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseIcon = "http://www.roblox.com/asset/?id=117431027"

	ADSTween = TweenService:Create(
		CurrentCamera,
		TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ FieldOfView = GunConfig.ADS_FOV }
	)
	ADSTween:Play()
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

	GunEquipConn = gun.Equipped:Connect(function(_: Mouse)
		AimAndDisplayCrosshair(gun)

		self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = true

				self.janitor:Remove("RayHit")
				ADSTweenZoom(gun)
			end
		end))

		self.janitor:Add(UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = false

				self.janitor:Remove("Rotate")
				AimAndDisplayCrosshair(gun)
				CancelADS()
			end
		end))

		self.janitor:Add(gun.Activated:Connect(function()
			if PlayerContext.Humanoid.health <= 0 then
				return
			end

			local shot = nil

			if HoldingRMB then
				shot = GunNetwork:fetch(
					"ShootGun",
					PlayerContext.Humanoid,
					CurrentCamera.CFrame.Position,
					CurrentCamera.CFrame.LookVector
				)
			else
				shot = GunNetwork:fetch("ShootGun", PlayerContext.Humanoid)
			end

			if shot then
				self:ActivateMuzzleFlash(gun)
				self:ApplyGunRecoil(gun)
				SoundManager.Play(GunData[gun.Name].ShootSoundName, {
					Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
				})
			else
				SoundManager.Play(GunData[gun.Name].ShootNoAmmoName, {
					Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
				})
			end
		end))
	end)

	GunDisconnectConn = gun.Unequipped:Connect(function()
		print("Disconnecting gun connections!")
		HoldingRMB = false
		self.janitor:Remove("Rotate")
		self.janitor:Remove("RayHit")
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
