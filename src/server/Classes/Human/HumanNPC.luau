local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data

local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Human = require(script.Parent.Human)
local HumanConstants = require(script.Parent.HumanConstants)

local UP = Vector3.yAxis

local HumanNPC = setmetatable({}, Human)
HumanNPC.__index = HumanNPC

function HumanNPC.new(humanoid: Humanoid)
	local self = setmetatable(Human.new(humanoid), HumanNPC)
	self.CurrentGun = Gun.new("Revolver", self, self.Character)
	self.HumanType = "NPC"
	self.RightArmAimer = self:InitializeRightArmAimer()
	self.CurrentGun:AddGunToInventory()
	self.NoiseSeed = RandomModule.GetRandom() * 1000
	self.AttackingTarget = false
	print(`New human class initiated for NPC {self.Character.Name}`)

	return self :: any
end
function HumanNPC:InitializeRightArmAimer()
	local aimer: AlignOrientation = Instance.new("AlignOrientation")
	local rightArm = self.BodyParts["RightUpperArm"]
	aimer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimer.Attachment0 = rightArm:WaitForChild("RightShoulderAttachment")
	aimer.RigidityEnabled = true
	aimer.Name = "RightArmAimer"
	aimer.MaxTorque = 90000
	aimer.MaxAngularVelocity = 15000
	aimer.Responsiveness = 150
	aimer.Enabled = false
	aimer.Parent = rightArm
	return aimer
end

function HumanNPC:ToggleRightArmAimer(enable: boolean)
	assert(self.RightArmAimer, "[HumanNPC:ToggleRightArmAimer] RightArmAimer is nil")
	if self.RightArmAimer.Enabled == enable then
		return
	end

	if enable then
		self.RightArmAimer.Enabled = true
	else
		self.RightArmAimer.Enabled = false
	end
end

function HumanNPC:AimRightArmTowards(target)
	local rightArm = self.BodyParts["RightUpperArm"]
	local origin = rightArm.Position

	local targetPos = target:IsA("Model") and target:GetPivot().Position or target.Position

	local lookCF = CFrame.lookAt(origin, targetPos)

	-- smooth time-based noise
	local t = os.clock() * HumanConstants.SWAY_SPEED
	local seed = self.NoiseSeed

	local yawNoise = math.noise(seed, t, 0)
	local pitchNoise = math.noise(seed, 0, t)

	local swayYaw = yawNoise * HumanConstants.SWAY_AMOUNT
	local swayPitch = pitchNoise * HumanConstants.SWAY_AMOUNT

	lookCF *= CFrame.Angles(math.rad(90) + swayPitch, swayYaw, 0)

	self.RightArmAimer.CFrame = lookCF
end
function HumanNPC:AttackPlayer(target: Model | BasePart)
	assert(target, "[HumanNPC:AttackPlayer] Target is invalid")

	self.AttackingTarget = true

	self:ToggleRightArmAimer(true)

	task.spawn(function()
		while task.wait(1) do
			if not self.AttackingTarget then
				return
			end
			self:AimRightArmTowards(target)
			self:NPCShoot()
		end
	end)
end

function HumanNPC:EquipGun(gunTool: Tool?)
	if not gunTool then
		error("[HumanNPC:EquipGun] gunTool is nil")
	end
	self.Humanoid:EquipTool(gunTool)
end

function HumanNPC:UnEquipCurrentTool()
	self.Humanoid:UnEquipTools()
end

function HumanNPC:NPCShoot()
	local currentGun = self.CurrentGun
	if not currentGun then
		return
	end

	local tool = currentGun.Tool
	if not tool then
		return
	end

	-- Cache these once on equip in production (see note below)
	local handle = tool:WaitForChild("Handle", 10)
	local shootPoint = tool:WaitForChild("ShootPoint", 10)
	local rightArm = self.BodyParts.RightUpperArm

	if not (handle and shootPoint and rightArm) then
		return
	end

	-- Fire weapon logic first
	currentGun:ShootGun()

	--recoil impulse
	local handleImpulse = handle.AssemblyMass * UP * 100
	handle:ApplyImpulseAtPosition(handleImpulse, shootPoint.WorldPosition)
end

function HumanNPC:OnDeath()
	Debris:AddItem(self.Character, 30)
	Human.OnDeath(self)
end

return HumanNPC
