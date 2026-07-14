local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ProceduralModule = require(ReplicatedStorage.Shared.ProceduralModule)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local Animal = {}
Animal.__index = Animal

function Animal.new(model: Model?, type: string)
	assert(model, "Missing animal model")
	assert(type, "Missing animal type")
	local self = setmetatable({}, Animal)
	self.Model = model
	self.Name = model.Name
	self.Janitor = Janitor.new()
	self.Health = 100
	self.Target = workspace:FindFirstChild("Target")
	self.RaycastParams = nil
	self.Type = type
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.AlignOrientation = nil
	self.HRP = model:FindFirstChild("HumanoidRootPart")
	self.IKTargets = {}
	self.RaycastParts = {}
	self.IKControls = {}

	self:Initialize()

	return self
end

function Animal:SetupPoles()
	if not self.HRP then
		warn("Missing HRP reference of animation class")
		return
	end

	local ikControls = self.IKControls

	if
		not ikControls
		or not ikControls.LeftFront
		or not ikControls.LeftBack
		or not ikControls.RightFront
		or not ikControls.RightBack
	then
		warn("IKControls references not all valid or is missing")
		return
	end

	ikControls.LeftFront.Pole = Utility.GetInstance(self.HRP, false, "LeftFrontPole")
	ikControls.LeftBack.Pole = Utility.GetInstance(self.HRP, false, "LeftBackPole")
	ikControls.RightFront.Pole = Utility.GetInstance(self.HRP, false, "RightFrontPole")
	ikControls.RightBack.Pole = Utility.GetInstance(self.HRP, false, "RightBackPole")
end

function Animal:ObtainIKReferences()
	if not self.Model then
		warn("Cannot get IK references, missing model")
		return
	end
	local model = self.Model

	-- Uses recursive option so we don't have to specifically supply the exact path
	self.IKTargets = {
		Folder = Utility.GetInstance(model, false, "IKTargets"),
		LeftFront = Utility.GetInstance(model, false, "LeftFrontIKTarget"),
		LeftBack = Utility.GetInstance(model, false, "LeftBackIKTarget"),
		RightFront = Utility.GetInstance(model, false, "RightFrontIKTarget"),
		RightBack = Utility.GetInstance(model, false, "RightBackIKTarget"),
	}
	self.RaycastParts = {
		Folder = Utility.GetInstance(model, false, "RaycastParts"),
		LeftFront = Utility.GetInstance(model, false, "LeftFrontRaycastPart"),
		LeftBack = Utility.GetInstance(model, false, "LeftBackRaycastPart"),
		RightFront = Utility.GetInstance(model, false, "RightFrontRaycastPart"),
		RightBack = Utility.GetInstance(model, false, "RightBackRaycastPart"),
	}
	self.IKControls = {
		LeftFront = Utility.GetInstance(model, false, "LeftFrontIK"),
		LeftBack = Utility.GetInstance(model, false, "LeftBackIK"),
		RightFront = Utility.GetInstance(model, false, "RightFrontIK"),
		RightBack = Utility.GetInstance(model, false, "RightBackIK"),
	}
	self.AlignOrientation = Utility.GetInstance(model, false, "AlignOrientation")
end

function Animal:RaycastExclude()
	if not self.Model then
		warn("Animal class cannot exclude. Empty model reference")
		return
	end
	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterDescendantsInstances = { self.Model }
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
end

function Animal:Activate()
	local root = self.HRP
	if not root then
		warn("Cannot start animal class, missing HRP ref")
		return
	end

	-- Alignment fix when traversing at an angle
	self.Janitor:Add(
		RunService.Heartbeat:Connect(function()
			if not self.Target or not self.AlignOrientation then
				return
			end
			local raycast = workspace:Raycast(root.Position, -1000 * root.CFrame.UpVector, self.RaycastParams)

			if not raycast then
				return
			end
			local rotateToFloorCFrame = ProceduralModule:getRotationBetween(root.CFrame.UpVector, raycast.Normal)
			local floorOrientedCFrame = rotateToFloorCFrame * CFrame.new(root.Position)

			local dz = (root.Position.Z - self.Target.Position.Z)
			local dx = (root.Position.X - self.Target.Position.X)
			local horizontalAngle = math.atan2(dx, dz)

			self.AlignOrientation.CFrame = floorOrientedCFrame.Rotation * CFrame.fromOrientation(0, horizontalAngle, 0)
		end),
		"Disconnect",
		"AnimalOrientationConn"
	)

	task.spawn(function()
		while self and self.Model do
			ProceduralModule:IkLegStep(
				self.IKTargets.LeftFront,
				self.RaycastParts.LeftFront,
				self.Target,
				2,
				2,
				1,
				0.05,
				self.RayCastParams
			)
			ProceduralModule:IkLegStep(
				self.IKTargets.RightBack,
				self.RaycastParts.RightBack,
				self.Target,
				2,
				2,
				1,
				0.05,
				self.RayCastParams
			)
			task.wait(0.1)
			ProceduralModule:IkLegStep(
				self.IKTargets.RightFront,
				self.RaycastParts.RightFront,
				self.Target,
				2,
				2,
				1,
				0.05,
				self.RayCastParams
			)
			ProceduralModule:IkLegStep(
				self.IKTargets.LeftBack,
				self.RaycastParts.LeftBack,
				self.Target,
				2,
				2,
				1,
				0.05,
				self.RayCastParams
			)
		end
	end)
end

function Animal:Initialize()
	self:ObtainIKReferences()
	self:SetupPoles()
	self:RaycastExclude()
	self:Activate()
end

function Animal:Destroy()
	self.Janitor:Destroy()
	table.clear(self)
	setmetatable(self, nil)
end
return Animal
