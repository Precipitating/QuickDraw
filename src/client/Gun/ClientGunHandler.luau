local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PopupHandler = require(script.Parent.Parent.GUI.PopupHandler)
local ClientVetraContext = require(script.Parent.Parent.ClientProjectilesHandler.ClientVetraContext)
local EffectsDisplayer = require(script.Parent.Parent.VisualEffectsHandler.EffectsDisplayer)
local CrosshairHandler = require(script.Parent.Parent.GUI.CrosshairHandler)
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)
local GunConfig = require(script.Parent.GunConfig)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PlayerContext = require(script.Parent.Parent.Utility.PlayerContext)
local Networker = require(ReplicatedStorage.Packages.Networker).client
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local GunData = require(ReplicatedStorage.Shared.GunData.GunData)
local GunDataTypes = require(ReplicatedStorage.Shared.GunData.GunDataTypes)
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Vetra = require(ReplicatedStorage.Shared.Vetra)

type Networker = NetworkClient
type GunData = GunDataTypes.GunData

local ClientGunHandler = {}
ClientGunHandler.janitor = Janitor.new()
local GunNetwork = Networker.new("GunNetwork", ClientGunHandler)
local CurrentCamera = workspace.CurrentCamera
local ADSTween = nil
local ADSTweenInfo = TweenInfo.new(GunConfig.ADS_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local GunEquipConn = nil
local GunDisconnectConn = nil

local LastCrosshairHit = 0
local LastShot = 0

local Crosshair3DPosition = nil
local Crosshair3DSize = nil

local HoldingRMB = false

local HOLD_THRESHOLD = 0.2
local CAN_RELOAD_AFTER_SHOT_THRESHOLD = 0.2
local HoldingLMB = nil
local HoldingLMBStart = nil

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

local crosshairRaycastParams = RaycastParams.new()
crosshairRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
local gunRaycastParams = RaycastParams.new()
gunRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

function ClientGunHandler:StopReloading()
	PlayerContext.Reloading = false
	GunNetwork:fire("StopReloadingServer")
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
		local limbDestroyed = part:GetAttribute("Destroyed")
		if limbDestroyed then
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
	maxTravelDistance: number
): Vector3?
	local GRAVITY = workspace.Gravity
	local dt = 0.05
	local STEPS = math.ceil(maxTravelDistance / (initialVelocity * dt)) + 10
	local prevPos = shootOrigin
	local vel = direction * initialVelocity

	for _ = 1, STEPS do
		local speed = vel.Magnitude
		local dragAccel = -vel.Unit * dragCoefficient * speed * speed
		local gravAccel = Vector3.new(0, -GRAVITY, 0)
		local totalAccel = dragAccel + gravAccel

		local nextPos = prevPos + vel * dt + 0.5 * totalAccel * dt * dt

		vel = vel + totalAccel * dt

		if (nextPos - shootOrigin).Magnitude >= maxTravelDistance then
			return nil
		end

		local result = workspace:Raycast(prevPos, nextPos - prevPos, crosshairRaycastParams)
		if result then
			return result.Position
		end

		prevPos = nextPos
	end

	return prevPos
end

local function CastBarrelRay(crosshairBB: BillboardGui, gunTool: Tool, shootPoint: Attachment)
	if not shootPoint then
		warn("Casting ray failed, shootpoint nil")
		return
	end
	local gunName = gunTool.Name
	local gunData = GunData[gunName]
	local bulletVelocity = gunData.Velocity
	local dragCoefficient = gunData.DragCoefficient or 0
	local maxCrosshairDistance = GunData[gunName].MaxSimulationDistance or 1000
	local origin: Vector3 = shootPoint.WorldPosition
	local direction: Vector3 = shootPoint.WorldAxis

	crosshairRaycastParams.ExcludeInstances = { PlayerContext.Character, gunTool }
	local landLocation = PredictBulletLanding(origin, direction, bulletVelocity, dragCoefficient, maxCrosshairDistance)

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
	crosshairRaycastParams.ExcludeInstances = { PlayerContext.Character, gunTool, crosshairPart }

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
			CastBarrelRay(crosshairBB, gunTool, shootPoint)

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

	EffectsDisplayer:DisplayMuzzleFlash(gunTool)
	EffectsDisplayer.networker:fire("DisplayMuzzleFlashToOthers", gunTool)

	self:ApplyGunRecoil(gunTool)
	SoundManager.PlayKeyed("SFX", gunData.ShootSoundName, {
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
	local currAmmo, maxAmmo, ammoReserve = GunNetwork:fetch("GetAmmoCount")

	if os.clock() - LastShot < CAN_RELOAD_AFTER_SHOT_THRESHOLD then
		return
	end

	if GunNetwork:fetch("IsGunJammed") then
		GunNetwork:fire("UnjamGun")
		return
	end

	if currAmmo == maxAmmo or PlayerContext.Humanoid.Health <= 0 then
		return
	end

	if ammoReserve <= 0 then
		return
	end

	PlayerContext.Reloading = true
	local newAmmoCount = GunNetwork:fetch("Reload")
	if not currAmmo or maxAmmo then
		return
	end

	if newAmmoCount >= maxAmmo then
		self:StopReloading()
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

function ClientGunHandler:AfterShot()
	GunNetwork:fire("ReduceGunAmmo")
	GunNetwork:fire("GunJamIfRolled")

	if PlayerContext.Reloading then
		PopupHandler:NewPopup(1, "Cancelled reload")
		self:StopReloading()
	end
end

function ClientGunHandler:SingleShot(shootAttachment: Attachment, gunTool: Tool, gunData)
	local context = nil
	if HoldingRMB then
		context = ClientVetraContext.Vetra.BulletContext.new({
			Origin = CurrentCamera.CFrame.Position + (CurrentCamera.CFrame.LookVector * 7),
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

	ClientGunHandler:AfterShot()
end
function ClientGunHandler:SpreadShot(shootAttachment: Attachment, gunTool: Tool, gunData)
	local context = nil

	local pelletCount = gunData.PelletsPerShot
	local maxSpreadAngle = gunData.MaxSpreadAngle

	if HoldingRMB then
		for _ = 1, pelletCount do
			local spreadDir = Utility.GetShotgunSpreadDirection(CurrentCamera.CFrame.LookVector, maxSpreadAngle)
			context = Vetra.BulletContext.new({
				Origin = CurrentCamera.CFrame.Position + (CurrentCamera.CFrame.LookVector * 7),
				Direction = spreadDir,
				Speed = gunData.Velocity,
				RaycastParams = gunRaycastParams,
			})

			ClientVetraContext.Net:Fire(context, gunTool.Name)
		end
	else
		for _ = 1, pelletCount do
			local spreadDir = Utility.GetShotgunSpreadDirection(shootAttachment.WorldAxis, maxSpreadAngle)
			context = Vetra.BulletContext.new({
				Origin = shootAttachment.WorldPosition,
				Direction = spreadDir,
				Speed = gunData.Velocity,
				RaycastParams = gunRaycastParams,
			})

			ClientVetraContext.Net:Fire(context, gunTool.Name)
		end
	end
	ClientGunHandler:AfterShot()
end

function ClientGunHandler:ShootGun(gunTool: Tool, gunData)
	gunRaycastParams.ExcludeInstances = { gunTool, PlayerContext.Character }
	-- get shooting point (for non ADS)
	local shootAttachment: Attachment? = Utility.GetInstance(gunTool, true, "ShootPoint")
	if not shootAttachment then
		warn("[CLIENT] Missing gun shoot attachment of current tool")
		return
	end

	-- holding RMB means the bullet will fire via camera's lookvector
	-- else gun barrel

	task.spawn(function()
		if gunData.GunType == "Shotgun" then
			self:SpreadShot(shootAttachment, gunTool, gunData)
		else
			self:SingleShot(shootAttachment, gunTool, gunData)
		end
	end)

	self:DisplayGunEffects(gunTool)
end

function ClientGunHandler:ConnectAmmoGUI(gun: Tool)
	local gui: ScreenGui = Utility.GetInstance(PlayerContext.PlayerGui, true, "Ammo")
	local currentAmmo: number = gun:GetAttribute("CurrentAmmo") :: number
	local ammoReserve: number = gun:GetAttribute("AmmoReserve") :: number
	local currentAmmoLabel: TextLabel = Utility.GetInstance(gui, true, "BG", "CurrentAmmo")
	local ammoReserveLabel: TextLabel = Utility.GetInstance(gui, true, "BG", "AmmoReserve")
	if not currentAmmo or not ammoReserve then
		warn("Client missing gun's Int Values")
		return
	end

	if not currentAmmoLabel or not ammoReserveLabel then
		warn("Client missing ammo gui labels")
		return
	end
	local currAmmo, _, ammoReserves = GunNetwork:fetch("GetAmmoCount")
	currentAmmoLabel.Text = tostring(currAmmo)
	ammoReserveLabel.Text = tostring(ammoReserves)

	self.janitor:Add(gun:GetAttributeChangedSignal("CurrentAmmo"):Connect(function()
		if not currentAmmoLabel then
			warn("Missing current ammo label")
			return
		end
		currentAmmoLabel.Text = tostring(gun:GetAttribute("CurrentAmmo"))
	end))
	self.janitor:Add(gun:GetAttributeChangedSignal("AmmoReserve"):Connect(function()
		if not ammoReserveLabel then
			warn("Missing current ammo reserve label")
			return
		end
		ammoReserveLabel.Text = tostring(gun:GetAttribute("AmmoReserve"))
	end))
end

function ClientGunHandler:ToggleAmmoGUI(enabled: boolean)
	local gui: ScreenGui = Utility.GetInstance(PlayerContext.PlayerGui, true, "Ammo")
	if not gui then
		warn("Missing Ammo GUI ref!")
		return
	end

	gui.Enabled = enabled
end

function ClientGunHandler:TryShoot(gunTool: Tool?)
	if not gunTool then
		return
	end
	if PlayerContext.Humanoid.Health <= 0 then
		return
	end
	local gunData = GunData[gunTool.Name]
	local now = os.clock()
	if now - LastShot < gunData.ShotDelay then
		return
	end
	LastShot = now
	local currAmmo = gunTool:GetAttribute("CurrentAmmo")
	if currAmmo and currAmmo <= 0 or GunNetwork:fetch("IsGunJammed") then
		SoundManager.Play(gunData.ShootNoAmmoName, {
			Pitch = 1 + (RandomModule.GetRandom() - 0.5) * 0.1,
		})
		return
	end
	self:ShootGun(gunTool, GunData[gunTool.Name])
end
function ClientGunHandler:ConnectGun(gunTool: Tool?)
	if not gunTool then
		error("Can't connect guns, tool reference not valid!")
	end
	warn(`[CLIENT] Connecting {gunTool.Name}`)

	if GunEquipConn and GunDisconnectConn then
		GunEquipConn:Disconnect()
		GunDisconnectConn:Disconnect()
	end

	GunEquipConn = gunTool.Equipped:Connect(function(_: Mouse)
		-- arm moves where camera is looking + 3D crosshair
		local _: Part, crosshairBB: BillboardGui, _: ImageLabel = Get3DCrosshair()
		AimAndDisplayCrosshair(gunTool)
		ApplyCameraGunRecoil()
		self:ToggleAmmoGUI(true)
		self:ConnectAmmoGUI(gunTool)

		self:AddCollisionConstraints(gunTool)

		-- We use this because we disabled the default RMB camera movement by sinking RMB, but we want RMB to work
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
			-- Reload
			if input.KeyCode == Enum.KeyCode.R then
				self:AttemptReload()
			end
		end))

		-- Single shot
		self.janitor:Add(gunTool.Activated:Connect(function()
			self:TryShoot(gunTool)
		end))

		-- Held down LMB, only for guns with "Automatic" type
		ContextActionService:BindAction("LMBHeldAction", function(_, inputState, _)
			if inputState == Enum.UserInputState.Begin then
				HoldingLMBStart = os.clock()
				HoldingLMB = false
			elseif inputState == Enum.UserInputState.End then
				HoldingLMBStart = nil
				HoldingLMB = false
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)

		local gunType = GunData[gunTool.Name] and GunData[gunTool.Name].GunType
		if not gunType then
			return
		end

		self.janitor:Add(RunService.Heartbeat:Connect(function()
			if HoldingLMBStart and not HoldingLMB then
				if os.clock() - HoldingLMBStart >= HOLD_THRESHOLD then
					HoldingLMB = true
				end
			end

			if gunType ~= "Automatic" then
				return
			end

			if HoldingLMB then
				self:TryShoot(gunTool)
			end
		end))
	end)

	GunDisconnectConn = gunTool.Unequipped:Connect(function()
		warn(`[CLIENT] Disconnecting {gunTool.Name} connection`)
		self:ToggleAmmoGUI(false)
		HoldingRMB = false
		ContextActionService:UnbindAction("ADSAction")
		ContextActionService:UnbindAction("LMBHeldAction")
		CurrentCamera.CameraSubject = PlayerContext.Humanoid
		self:DisconnectGun()
		ClientGunHandler.CancelADS()
		PlayerContext.RightArmYaw.Enabled = false
		self.janitor:Cleanup()
	end)
end

function ClientGunHandler:DisconnectGun()
	warn("Gun disconnected!")
	if HoldingRMB then
		ClientGunHandler.CancelADS()
	end

	if PlayerContext.Reloading then
		self:StopReloading()
	end
	self.janitor:Cleanup()
end

function ClientGunHandler:DisplayBloodHit(position: Vector3?, normal: Vector3?)
	EffectsDisplayer:DisplayBloodHit(position, normal)
end

return ClientGunHandler
