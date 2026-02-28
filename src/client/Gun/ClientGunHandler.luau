local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CrosshairHandler = require(script.Parent.Parent.GUI.CrosshairHandler)
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)
local GunConfig = require(script.Parent.GunConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PoolHandler = require(script.Parent.Parent.Pools.PoolHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
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
local ADSTweenInfo = TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local HoldingRMB = false
local GunEquipConn = nil
local GunDisconnectConn = nil
local LastCrosshairHit = 0
local Crosshair3DPosition = nil
local Crosshair3DSize = nil

-- for camera recoil
local RecoilSpring = Ripple.createSpring(0, {
	dampingRatio = 0.6,
	frequency = 5,
})

local CrosshairSpring = Ripple.createSpring(Vector3.zero, {
	dampingRatio = 1,
	frequency = 50,
})

local CrosshairScaleSpring = Ripple.createSpring(UDim2.fromScale(1, 1), {
	dampingRatio = 1,
	frequency = 5,
})

local FastCast = FastCastRedux.new()

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

	-- also make camera flick up via springs
	RecoilSpring:impulse(GunData[gunTool.Name].CameraRecoil)
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

local function Get3DCrosshair()
	local crosshairPart = Utility.GetInstance(workspace, true, "Crosshair")
	local crosshairBillboard = Utility.GetInstance(crosshairPart, true, "CrosshairBB")
	local crosshairImage = Utility.GetInstance(crosshairBillboard, true, "ImageLabel")
	return crosshairPart, crosshairBillboard, crosshairImage
end

function ClientGunHandler.TweenADS(tweenIn: boolean)
	StopCurrentTween()
	if tweenIn then
		ADSTween = TweenService:Create(CurrentCamera, ADSTweenInfo, { FieldOfView = GunConfig.ADS_FOV })
	else
		ADSTween = TweenService:Create(CurrentCamera, ADSTweenInfo, { FieldOfView = GunConfig.NORMAL_FOV })
	end

	ADSTween:Play()
end

function ClientGunHandler.CancelADS()
	StopCurrentTween()
	local _: Part, crosshairBB: BillboardGui, _: ImageLabel = Get3DCrosshair()
	crosshairBB.Enabled = false

	CurrentCamera.CameraSubject = PlayerContext.Humanoid
	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MAX_ZOOM_DIST
	ADSTransparency(false)
	CrosshairHandler:ToggleCrosshairVisibility(false)

	ClientGunHandler.TweenADS(false)
end

local function DisableCrosshairIfOOB(crosshairBB: BillboardGui)
	-- disable crosshair if its aiming at sky or out of boundss
	local currentTime = os.clock()
	if (currentTime - LastCrosshairHit) > 0.01 and crosshairBB.Enabled then
		crosshairBB.Enabled = false
		Crosshair3DPosition = nil
		Crosshair3DSize = nil
	end
end

local function CrosshairSpringMovement(crosshairPart: Part, crosshairImg: ImageLabel, dt: number)
	if Crosshair3DPosition then
		CrosshairSpring:setGoal(Crosshair3DPosition)
		local smoothed = CrosshairSpring:step(dt)
		crosshairPart.Position = smoothed
	end
	if Crosshair3DSize then
		CrosshairScaleSpring:setGoal(Crosshair3DSize)
		local smoothed = CrosshairScaleSpring:step(dt)
		crosshairImg.Size = smoothed
	end
end

local function CastBarrelRay(gunName: string, shootPoint: Attachment)
	if not shootPoint then
		warn("Casting ray failed, shootpoint nil")
		return
	end
	local BulletVelocity = GunData[gunName].Velocity
	local origin: Vector3 = shootPoint.WorldPosition
	local direction: Vector3 = shootPoint.WorldCFrame.LookVector

	FastCast:Fire(origin, direction, BulletVelocity, ProjectileData)
end

local function Crosshair3DPositionSetter(crosshairBB: BillboardGui)
	ClientGunHandler.janitor:Add(
		FastCast.RayHit:Connect(function(_, rayHitResult: RaycastResult, _)
			if rayHitResult then
				if not crosshairBB.Enabled then
					crosshairBB.Enabled = true
				end
				local dist = (rayHitResult.Position - CurrentCamera.CFrame.Position).Magnitude
				local scale = math.max(0.25, dist / 50)
				Crosshair3DSize = UDim2.fromScale(1 * scale, 1 * scale)

				Crosshair3DPosition = rayHitResult.Position

				LastCrosshairHit = os.clock()
			end
		end),
		"Disconnect",
		"RayHit"
	)
end

local function ApplyCameraGunRecoil()
	RunService:BindToRenderStep("Recoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local val = RecoilSpring:step(dt)
		CurrentCamera.CFrame = CurrentCamera.CFrame * CFrame.Angles(math.rad(val), 0, 0)
	end)

	ClientGunHandler.janitor:Add(function()
		RunService:UnbindFromRenderStep("Recoil")
	end, true, "Recoil")
end

local function AimAndDisplayCrosshair(gunTool: Tool)
	local character = PlayerContext.Character

	local rightShoulder = Utility.GetInstance(character, true, "RightUpperArm", "RightShoulder")
	local rightShoulderAttachment: Attachment = rightShoulder.Attachment0
	local rightShoulderOriginalCF: CFrame = rightShoulderAttachment.CFrame

	local crosshairPart: Part, crosshairBB: BillboardGui, crosshairImg: ImageLabel = Get3DCrosshair()
	local shootPoint = gunTool:WaitForChild("ShootPoint", 10) :: Attachment
	ProjectileData.RaycastParams.FilterDescendantsInstances =
		{ PlayerContext.Character, gunTool:FindFirstChild("Frame"), crosshairPart }

	local parentPart = if HumanNetwork.networker:fetch("IsLegless")
		then PlayerContext.HRP
		else PlayerContext.BodyParts["UpperTorso"]

	-----------------------------------------------------------------------
	-- BindToRenderStep at the very end so nothing overwrites us
	-----------------------------------------------------------------------
	PlayerContext.RightArmYaw.Enabled = true
	RunService:BindToRenderStep("ADS_RotateAndTilt", Enum.RenderPriority.Last.Value, function(dt)
		local camLook = CurrentCamera.CFrame.LookVector
		local parentCF = parentPart.CFrame

		-- Get pitch from camera
		local pitch = math.asin(math.clamp(camLook.Y, -1, 1))
		pitch = math.clamp(pitch, -math.rad(90), math.rad(90))

		-- Use parent's flat forward as the base direction
		local flatForward = (parentCF.LookVector * Vector3.new(1, 0, 1)).Unit

		-- Build a direction vector with parent's yaw + camera's pitch
		local direction = (flatForward * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)).Unit

		-- Arm points down by default, so the "up" vector keeps roll stable
		local targetCF = CFrame.lookAt(Vector3.zero, direction, parentCF.UpVector) * CFrame.Angles(math.rad(90), 0, 0) -- attachment offset

		PlayerContext.RightArmYaw.CFrame = targetCF
		if not HoldingRMB then
			CastBarrelRay(gunTool.Name, shootPoint)

			if crosshairBB.Enabled then
				CrosshairSpringMovement(crosshairPart, crosshairImg, dt)
			end
			DisableCrosshairIfOOB(crosshairBB)
		end
	end)

	-----------------------------------------------------------------------
	-- Cleanup: unbind + restore the attachment to its original pose
	-----------------------------------------------------------------------
	ClientGunHandler.janitor:Add(function()
		RunService:UnbindFromRenderStep("ADS_RotateAndTilt")
		rightShoulderAttachment.CFrame = rightShoulderOriginalCF
		crosshairBB.Enabled = false
	end, true, "Rotate")
end

local function ADSTweenZoom(gunTool: Tool)
	StopCurrentTween()

	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MIN_ZOOM_DIST
	CurrentCamera.CameraSubject = gunTool:FindFirstChild("AimPos")
	ADSTransparency(true)
	CrosshairHandler:ToggleCrosshairVisibility(true, "Gun")

	ClientGunHandler.TweenADS(true)
end

function ClientGunHandler:DisplayGunEffects(gun: Tool, shot: boolean)
	-- display gun effects
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
		-- arm moves where camera is looking + 3D crosshair
		local _: Part, crosshairBB: BillboardGui, _: ImageLabel = Get3DCrosshair()
		AimAndDisplayCrosshair(gun)
		ApplyCameraGunRecoil()
		Crosshair3DPositionSetter(crosshairBB)

		self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end

			-- RMB = aim down sight
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = true
				crosshairBB.Enabled = false
				Crosshair3DPosition = nil
				Crosshair3DSize = nil
				self.janitor:Remove("RayHit")
				ADSTweenZoom(gun)
			end

			-- fix right arm orientation if pressed
			if input.KeyCode == Enum.KeyCode.Q then
				local rightArm = PlayerContext.BodyParts["RightUpperArm"]
				if rightArm then
					local shoulder: AnimationConstraint = rightArm:WaitForChild("RightShoulder", 10)
					if not shoulder then
						warn("Missing shoulder ref when fixing arm")
						return
					end
					shoulder.Enabled = false
					task.wait()
					shoulder.Enabled = true
				end
			end
		end))

		self.janitor:Add(UserInputService.InputEnded:Connect(function(input)
			-- get out of aim down sight and revert back to 3D crosshair aiming
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				HoldingRMB = false
				ClientGunHandler.CancelADS()
				Crosshair3DPositionSetter(crosshairBB)
			end
		end))

		self.janitor:Add(gun.Activated:Connect(function()
			if PlayerContext.Humanoid.health <= 0 then
				return
			end

			local shot = nil

			-- holding RMB means the bullet will fire via camera's lookvector
			-- else gun barrel
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

			self:DisplayGunEffects(gun, shot)
		end))
	end)

	GunDisconnectConn = gun.Unequipped:Connect(function()
		print("Disconnecting gun connections!")
		HoldingRMB = false
		self.janitor:Cleanup()
		CurrentCamera.CameraSubject = PlayerContext.Humanoid
		self:DisconnectGun()
		ClientGunHandler.CancelADS()
		PlayerContext.RightArmYaw.Enabled = false
	end)
end

function ClientGunHandler:DisconnectGun()
	warn("Gun disconnected!")
	if HoldingRMB then
		ClientGunHandler.CancelADS()
	end
	self.janitor:Cleanup()
end

function ClientGunHandler:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	assert(position, "Can't apply blood to position, POSITION is nil on DisplayBloodHit")
	assert(normal, "Can't apply blood to position, normal is nil on DisplayBloodHit")

	local hitPos = CFrame.lookAt(position, position + normal)

	local availableBlood: Part = PoolHandler.BloodPool:Acquire()
	assert(availableBlood, "Can't find available blood from its pool, does it exist?")

	availableBlood:PivotTo(hitPos)

	-- enable blood and disable after a short time
	for _, particle in ipairs(availableBlood:GetChildren()) do
		particle:Emit(1)
	end
end

return GunNetwork
