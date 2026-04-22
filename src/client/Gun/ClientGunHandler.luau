local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ClientVetraContext =
	require(StarterPlayer.StarterPlayerScripts.Client.ClientProjectilesHandler.ClientVetraContext)
local CrosshairHandler = require(script.Parent.Parent.GUI.CrosshairHandler)
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)
local GunConfig = require(script.Parent.GunConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PoolHandler = require(script.Parent.Parent.Pools.PoolHandler)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
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
local LastShot = 0
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

--local FastCast = FastCastRedux.new()

local crosshairRaycastParams = RaycastParams.new()
crosshairRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
local gunRaycastParams = RaycastParams.new()
gunRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

function ClientGunHandler:StopReloading()
	PlayerContext.Reloading = false
end

function ClientGunHandler:ActivateMuzzleFlash(gunTool: Tool?)
	if not gunTool then
		warn("Client gunTool invalid")
		return
	end
	local muzzleFolder = Utility.GetInstance(gunTool, true, "MuzzleFlash", "Attachment")

	if not muzzleFolder then
		return
	end

	for _, effect in muzzleFolder:GetChildren() do
		if effect:IsA("SpotLight") then
			effect.Enabled = true
			task.delay(0.1, function()
				if effect then
					effect.Enabled = false
				end
			end)
			continue
		end
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
	for _, part in PlayerContext.Character:GetDescendants() do
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
	CurrentCamera.CameraSubject = PlayerContext.Humanoid
	PlayerContext.Player.CameraMaxZoomDistance = GunConfig.NORMAL_MAX_ZOOM_DIST

	StopCurrentTween()
	ClientGunHandler.TweenADS(false)

	local _: Part, crosshairBB: BillboardGui, _: ImageLabel = Get3DCrosshair()
	crosshairBB.Enabled = false
	ADSTransparency(false)
	CrosshairHandler:ToggleCrosshairVisibility(false)
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

local function PredictBulletLanding(
	shootOrigin: Vector3,
	direction: Vector3,
	initialVelocity: number,
	dragCoefficient: number,
	maxTravelDistance: number,
	minSpeed: number
): Vector3?
	local GRAVITY = workspace.Gravity
	local dt = 0.05
	local STEPS = math.ceil(maxTravelDistance / (initialVelocity * dt)) + 10 -- scale steps to gun
	crosshairRaycastParams.FilterDescendantsInstances = { PlayerContext.Character }
	local prevPos = shootOrigin
	local vel = direction * initialVelocity

	for i = 1, STEPS do
		local speed = vel.Magnitude
		if speed < minSpeed then
			break
		end

		local dragAccel = -vel.Unit * dragCoefficient * speed * speed
		local gravAccel = Vector3.new(0, -GRAVITY, 0)

		vel = vel + (dragAccel + gravAccel) * dt
		local nextPos = prevPos + vel * dt

		if (nextPos - shootOrigin).Magnitude >= maxTravelDistance then
			return nil -- bullet expired, hide crosshair
		end

		local result = workspace:Raycast(prevPos, nextPos - prevPos, crosshairRaycastParams)
		if result then
			return result.Position
		end

		prevPos = nextPos
	end

	return prevPos
end
local function CastBarrelRay(crosshairBB: BillboardGui, gunName: string, shootPoint: Attachment)
	if not shootPoint then
		warn("Casting ray failed, shootpoint nil")
		return
	end

	local bulletVelocity = GunData[gunName].Velocity
	local dragCoefficient = GunData[gunName].DragCoefficient or 0
	local maxCrosshairDistance = GunData[gunName].MaxSimulationDistance or 500
	local origin: Vector3 = shootPoint.WorldPosition
	local direction: Vector3 = shootPoint.WorldAxis
	local landLocation =
		PredictBulletLanding(origin, direction, bulletVelocity, dragCoefficient, maxCrosshairDistance, 36)

	if not landLocation then
		DisableCrosshairIfOOB(crosshairBB)
		return
	end

	if not crosshairBB.Enabled then
		crosshairBB.Enabled = true
	end

	local dist = (landLocation - CurrentCamera.CFrame.Position).Magnitude
	local scale = math.max(0.15, dist / 50)
	Crosshair3DSize = UDim2.fromScale(scale, scale)
	Crosshair3DPosition = landLocation
	LastCrosshairHit = os.clock()
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
	crosshairRaycastParams.FilterDescendantsInstances =
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

		PlayerContext.RightArmYaw.CFrame = targetCF * CFrame.Angles(math.rad(-5), 0, 0)
		if not HoldingRMB then
			CastBarrelRay(crosshairBB, gunTool.Name, shootPoint)

			if crosshairBB.Enabled then
				CrosshairSpringMovement(crosshairPart, crosshairImg, dt)
			end
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
-- display gun effects
function ClientGunHandler:DisplayGunEffects(gunTool: Tool)
	local gunData = GunData[gunTool.Name]

	self:ActivateMuzzleFlash(gunTool)
	self:ApplyGunRecoil(gunTool)
	SoundManager.Play(gunData.ShootSoundName, {
		Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
	})
	if gunData.LoadNextRoundName then
		SoundManager.Play(gunData.LoadNextRoundName)
	end
end

function ClientGunHandler:AttemptReload()
	if PlayerContext.Humanoid.Health <= 0 or PlayerContext.Reloading then
		return
	end
	local currAmmo, maxAmmo = GunNetwork:fetch("GetAmmoCount")

	if currAmmo == maxAmmo or PlayerContext.Humanoid.Health <= 0 then
		return
	end
	PlayerContext.Reloading = true
	local newAmmoCount = GunNetwork:fetch("Reload")

	if not currAmmo or maxAmmo then
		return
	end

	if newAmmoCount >= maxAmmo then
		PlayerContext.Reloading = false
		return
	end
end

function ClientGunHandler:AddCollisionConstraints(gunTool: Tool)
	local bodyParts = PlayerContext.BodyParts
	local gunParts = gunTool:GetChildren()
	for _, bodyPart in bodyParts do
		local collisionConstraint = Instance.new("NoCollisionConstraint")

		for _, gunPart in gunParts do
			if not gunPart:IsA("BasePart") then
				continue
			end
			collisionConstraint.Part0 = gunPart
			collisionConstraint.Part1 = bodyPart
			collisionConstraint.Parent = gunTool
		end
	end
end

function ClientGunHandler:ShootGun(gunTool: Tool, gunData)
	gunRaycastParams.FilterDescendantsInstances = { gunTool, PlayerContext.Character }
	-- get shooting point (for non ADS)
	local shootAttachment: Attachment? = Utility.GetInstance(gunTool, true, "ShootPoint")
	if not shootAttachment then
		warn("[CLIENT] Missing gun shoot attachment of current tool")
		return
	end

	local context = nil
	-- holding RMB means the bullet will fire via camera's lookvector
	-- else gun barrel
	if HoldingRMB then
		context = ClientVetraContext.Vetra.BulletContext.new({
			Origin = CurrentCamera.CFrame.Position,
			Direction = CurrentCamera.CFrame.LookVector,
			Speed = gunData.Velocity,
			RaycastParams = gunRaycastParams,
		})

		ClientVetraContext.Net:Fire(context, gunTool.Name)
	else
		context = ClientVetraContext.Vetra.BulletContext.new({
			Origin = shootAttachment.WorldPosition,
			Direction = shootAttachment.WorldAxis,
			Speed = gunData.Velocity,
			RaycastParams = gunRaycastParams,
		})

		ClientVetraContext.Net:Fire(context, gunTool.Name)
	end

	self:DisplayGunEffects(gunTool)
end

function ClientGunHandler:ConnectGun(gunTool: Tool?)
	print("connecting gun")
	if not gunTool then
		error("Can't connect guns, tool reference not valid!")
	end

	if GunEquipConn and GunDisconnectConn then
		GunEquipConn:Disconnect()
		GunDisconnectConn:Disconnect()
	end

	GunEquipConn = gunTool.Equipped:Connect(function(_: Mouse)
		-- arm moves where camera is looking + 3D crosshair
		local _: Part, crosshairBB: BillboardGui, _: ImageLabel = Get3DCrosshair()
		AimAndDisplayCrosshair(gunTool)
		ApplyCameraGunRecoil()

		self:AddCollisionConstraints(gunTool)

		-- we use this because we disabled the default RMB camera movement by sinking RMB, but we want RMB to work
		-- so we set this at a higher priority so we can still allow RMB inputs for this only
		ContextActionService:BindActionAtPriority("ADSAction", function(_, inputState, input)
			if inputState == Enum.UserInputState.Begin then
				HoldingRMB = true
				crosshairBB.Enabled = false
				Crosshair3DPosition = nil
				Crosshair3DSize = nil
				ADSTweenZoom(gunTool)
			elseif inputState == Enum.UserInputState.End then
				HoldingRMB = false
				ClientGunHandler.CancelADS()
			end
			return Enum.ContextActionResult.Pass -- still let RMB through to other listeners
		end, false, Enum.ContextActionPriority.Low.Value + 100, Enum.UserInputType.MouseButton2)

		self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			-- reload
			if input.KeyCode == Enum.KeyCode.R then
				self:AttemptReload()
			end
		end))

		self.janitor:Add(gunTool.Activated:Connect(function()
			if PlayerContext.Humanoid.Health <= 0 then
				return
			end

			local gunData = GunData[gunTool.Name]
			local now = os.clock()
			if now - LastShot < gunData.ShotDelay then
				return
			end
			LastShot = now
			local currAmmo, _ = GunNetwork:fetch("GetAmmoCount")

			-- no ammo, return early
			if currAmmo and currAmmo <= 0 then
				SoundManager.Play(gunData.ShootNoAmmoName, {
					Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
				})
				return
			end
			self:ShootGun(gunTool, gunData)
		end))
	end)

	GunDisconnectConn = gunTool.Unequipped:Connect(function()
		print("Disconnecting gun connections!")
		HoldingRMB = false
		self.janitor:Cleanup()
		ContextActionService:UnbindAction("ADSAction")
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

	if PlayerContext.Reloading then
		PlayerContext.Reloading = false
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
	for _, particle in availableBlood:GetChildren() do
		particle:Emit(1)
	end
end

return ClientGunHandler
