--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HumanNetwork = require(script.Parent.Parent.HumanNetwork)

local AnimationController = require(ReplicatedStorage.Shared.AnimationData.AnimationController)

--
local RunLoop = false
local CheckTime = 1
local RenderDistance = 300
--
local DefaultAnims = ReplicatedStorage.Shared.AnimationData.DefaultAnimations
local CrawlAnims = ReplicatedStorage.Shared.AnimationData.CrawlAnimations
--
local DefaultAnimateParams = {
	ApplyRigScale = true,
	SprintDetectSpeed = 30,
	SprintSpeedDividend = 16,
	RunDetectSpeed = 24,
	RunSpeedDividend = 16,
	WalkSpeedDividend = 6,
	JumpDuration = 0.3,
	ClimbSpeedDividend = 12,
	SwimSpeedDividend = 16,
	LandedDuration = 0.6,
}
local Camera: Camera = workspace:WaitForChild("Camera")
local AnimatedNPCS = {}

local NPCAnimationsHandler = {}

function NPCAnimationsHandler:Initialize()
	if RunLoop then
		return
	end
	RunLoop = true

	while task.wait(CheckTime) and RunLoop do
		for character, controller in AnimatedNPCS do
			if not character.Parent then
				self:RemoveNPCAnimationController(character)
				continue
			end

			-- Only play NPC anims if in range with camera
			local camToNPCDistance = (Camera.CFrame.Position - character:GetPivot().Position).Magnitude
			if camToNPCDistance <= RenderDistance then
				controller:Load()
			else
				controller:Unload()
			end
		end
	end
end

function NPCAnimationsHandler:GetNPCAnimations(key: Model?)
	if not key then
		return nil
	end

	return AnimatedNPCS[key]
end

function NPCAnimationsHandler:ToggleNPCAnimations(enable: boolean)
	RunLoop = enable
end

function NPCAnimationsHandler:AddNPCAnimationController(character: Model)
	task.spawn(function()
		if AnimatedNPCS[character] then
			self:RemoveNPCAnimationController(character)
		end
		local controller = nil
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			warn(`[NPCAnimationsHandler:AddNPCAnimationController] humanoid missing, can't initialize NPC animation`)
			return
		end
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if not hrp then
			warn(
				`[NPCAnimationsHandler:AddNPCAnimationController] HumanoidRootPart missing, can't initialize NPC animation`
			)
			return
		end
		local isLegless = HumanNetwork.networker:fetch("IsLegless", humanoid)
		if isLegless then
			controller = AnimationController.new(character, CrawlAnims, DefaultAnimateParams)
		else
			controller = AnimationController.new(character, DefaultAnims, DefaultAnimateParams)
		end
		AnimatedNPCS[character] = controller
	end)
end

function NPCAnimationsHandler:RemoveNPCAnimationController(character: Model)
	if AnimatedNPCS[character] then
		AnimatedNPCS[character] = nil
	end
end

return NPCAnimationsHandler
