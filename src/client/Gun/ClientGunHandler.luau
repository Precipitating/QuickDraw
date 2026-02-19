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

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {}

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
local function ADSTransparency(on: boolean)
	for _, part in pairs(PlayerContext.Character:GetDescendants()) do
		if not part:IsA("MeshPart") then
			continue
		end

		if part.Parent:IsA("Tool") then
			continue
		end

		if on then
			part.Transparency = 0.8
		else
			part.Transparency = 0
		end
	end
end

local function GetCrosshair()
	local crosshairPart = workspace:WaitForChild("Crosshair", 10)
	if not crosshairPart then
		warn("CrosshairPart missing")
		return
	end
	local crosshairBillboard = crosshairPart:WaitForChild("CrosshairBB", 10)
	if not crosshairBillboard then
		warn("CrosshairBillboard missing")
		return
	end

	local crosshairImage = crosshairBillboard:WaitForChild("ImageLabel")
	if not crosshairImage then
		warn("crosshairImage missing")
		return
	end

	return crosshairPart, crosshairBillboard, crosshairImage
end

local function CancelADS()
	StopCurrentTween()

	local _: Part, crosshairBB: BillboardGui, _: ImageLabel = GetCrosshair()
	crosshairBB.Enabled = false

	CurrentCamera.CameraSubject = PlayerContext.Humanoid
	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MAX_ZOOM_DIST
	ADSTransparency(false)
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
	local origin = shootPoint.WorldPosition
	local direction = shootPoint.WorldCFrame.LookVector * 1000

	return workspace:Raycast(origin, direction, rayParams)
end
local function ADSTweenZoom(gunTool: Tool)
	StopCurrentTween()

	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MIN_ZOOM_DIST
	CurrentCamera.CameraSubject = gunTool:FindFirstChild("AimPos")
	ADSTransparency(true)

	ADSTween = TweenService:Create(
		CurrentCamera,
		TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ FieldOfView = GunConfig.ADS_FOV }
	)
	ADSTween:Play()

	local character = PlayerContext.Character

	local rightShoulder = character:WaitForChild("RightUpperArm"):WaitForChild("RightShoulder")
	local rightShoulderAttachment: Attachment = rightShoulder.Attachment0
	local originalCF: CFrame = rightShoulderAttachment.CFrame -- cache rest pose

	-- crosshair
	local crosshairPart: Part, crosshairBB: BillboardGui, crosshairImage: ImageLabel = GetCrosshair()
	local shootPoint = gunTool:WaitForChild("ShootPoint", 10)

	rayParams.FilterDescendantsInstances = { PlayerContext.Character, gunTool:FindFirstChild("Frame"), crosshairPart }

	local BIND_NAME = "ADS_RotateAndTilt"

	-----------------------------------------------------------------------
	-- BindToRenderStep at the very end so nothing overwrites us
	-----------------------------------------------------------------------
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Last.Value, function()
		local camLook = CurrentCamera.CFrame.LookVector

		-- ── Pitch: tilt upper body to follow camera vertically ──
		local pitch, _, _ = CurrentCamera.CFrame:ToOrientation()
		pitch = math.clamp(pitch, -math.rad(40), math.rad(40))

		-- Animator writes to Transform, never to Attachment.CFrame,
		-- so this rotation persists and compounds with the animation.
		rightShoulderAttachment.CFrame = originalCF * CFrame.Angles(pitch, 0, 0)

		-- barrel raycast to 1000 units forward
		local rayHitResult = CastBarrelRay(shootPoint)

		-- setting crosshair via raycast result
		if rayHitResult then
			if not crosshairBB.Enabled then
				crosshairBB.Enabled = true
			end
			crosshairPart.Position = rayHitResult.Position
		else
			if crosshairBB.Enabled then
				crosshairBB.Enabled = false
			end
		end
	end)

	-----------------------------------------------------------------------
	-- Cleanup: unbind + restore the attachment to its original pose
	-----------------------------------------------------------------------
	ClientGunHandler.janitor:Add(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
		rightShoulderAttachment.CFrame = originalCF
	end, true, "Rotate")
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
