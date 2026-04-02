--!nonstrict
--[[
Adds new default animation options such as Swim, SwimIdle, Landed, LandedRoll, and Sprint.
Supports custom tool holding, tool idle, tool walk, and tool run animations.

For all tool animations, it follows the following format:
- ToolWalk -- Default Walk override.
- ToolRun -- Defaukt Run override.
- ToolIdle -- Default Idle override.
- ToolHolding -- Default ToolHolding override.

How to set a custom tool walk animation (and so for the others):
1. Place either an Animation or an ObjectValue under your tool
2. Name it ToolWalk and set the Animation's AnimationId or the ObjectValue's Value to an Animation

For the custom animations:
- Landed plays when reaching the ground after falling at a specific set speed.
- LadedRoll is just the same as Landed, but when at a higher speed.
- Swim and SwimIdle play when the Humanoid's state is changed to Swimming.

ANIMATION ATTRIBUTES:
- Weight (number) -- Sets the animation's weight (as in for the weighted chance).
- Looped (boolean) -- Sets the animation's Looped property. It uses the animation's default Looped if the value is nil.

By: Cassie (@GoulStorm)
Version: 1.1.4
]]

local runService = game:GetService("RunService")

export type AnimationName =
	"Idle"
	| "Climb"
	| "Fall"
	| "Jump"
	| "Sit"
	| "Walk"
	| "ToolHolding"
	| "Landed"
	| "LandedRoll"
	| "Run"
	| "Swim"
	| "SwimIdle"
	| "Sprint"

export type AnimateParams = {
	ApplyRigScale: boolean,
	SprintDetectSpeed: number,
	SprintSpeedDividend: number,
	RunDetectSpeed: number,
	RunSpeedDividend: number,
	WalkSpeedDividend: number,
	JumpDuration: number,
	ClimbSpeedDividend: number,
	SwimSpeedDividend: number,
	LandedDuration: number,
}

export type Animations = { [AnimationName]: Animation | { Animation } }

export type AnimationRegister = {
	Animation: Animation,
	AnimationTrack: AnimationTrack,
	Weight: number,
}

export type AnimationRegisterGroup = {
	TotalWeight: number,
	Animations: { AnimationRegister },
}

export type PlayAnimationParams = {
	Duration: number?, -- Sets speed such that it has the given total duration.
	Speed: number?,
	Weight: number?,
	FadeTime: number?,
	Priority: Enum.AnimationPriority?,
}

local function GetAnimationTrack(from: AnimationRegisterGroup): AnimationTrack
	local totalWeight = from.TotalWeight
	local randomValue = math.random() * totalWeight
	local cumulativeWeight = 0

	for key, value in from.Animations do
		cumulativeWeight += value.Weight

		if randomValue <= cumulativeWeight then
			return value.AnimationTrack
		end
	end

	error("Unexpected error, couldn't return a random AnimationTrack.")
end

local constructor = {}
local controller = {}
controller.__index = controller

type TableContent = {
	Character: Model,
	Humanoid: Humanoid,
	Animator: Animator,
	RootPart: BasePart,
	IsLoaded: boolean,
	Connections: { { Disconnect: (self: any) -> () } },
	DefaultAnimations: Animations,
	Animations: Animations,
	AnimationRegisters: { [string]: AnimationRegisterGroup },
	AnimateParams: AnimateParams,
	Reload: boolean?,
}
export type AnimateController = setmetatable<TableContent, typeof(controller)>

local function DeepClone<T>(t: T): T
	local clone = table.clone(t)

	for key, value in t do
		if type(value) == "table" then
			clone[key] = DeepClone(value)
		end
	end

	return clone
end

constructor.R15AnimateParams = {
	ApplyRigScale = true,
	SprintDetectSpeed = 24,
	SprintSpeedDividend = 16,
	RunDetectSpeed = 14,
	RunSpeedDividend = 16,
	WalkSpeedDividend = 10,
	JumpDuration = 0.3,
	ClimbSpeedDividend = 12,
	SwimSpeedDividend = 16,
	LandedDuration = 0.6,
} :: AnimateParams

constructor.R6AnimateParams = {
	ApplyRigScale = true,
	SprintDetectSpeed = 30,
	SprintSpeedDividend = 20,
	RunDetectSpeed = 20,
	RunSpeedDividend = 20,
	WalkSpeedDividend = 14,
	JumpDuration = 0.3,
	ClimbSpeedDividend = 12,
	SwimSpeedDividend = 16,
	LandedDuration = 0.6,
} :: AnimateParams

local function FolderToAnimations(folder: Instance): Animations
	local animations: Animations = {}

	for _, child in ipairs(folder:GetChildren()) do
		animations[child.Name] = child:IsA("Animation") and child or child:GetChildren()
	end

	return animations
end

-- Randomizes the AnimationTrack result given its weight value.
function constructor.new(
	character: Model,
	animations: Instance | Animations,
	animateParams: AnimateParams?
): AnimateController
	local tableAnimations = typeof(animations) == "Instance" and FolderToAnimations(animations) or DeepClone(animations)

	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local controllerTable = {
		Character = character,
		Humanoid = humanoid,
		Animator = animator,
		RootPart = rootPart,
		IsLoaded = false,
		Connections = {},
		AnimationRegisters = {},
		DefaultAnimations = tableAnimations,
		Animations = DeepClone(tableAnimations),
	}

	local fillInAnimateParams = humanoid.RigType == Enum.HumanoidRigType.R6 and constructor.R6AnimateParams
		or constructor.R15AnimateParams

	if animateParams then
		animateParams = table.clone(animateParams)

		for key, defaultValue in fillInAnimateParams do
			local currentValue = animateParams[key]

			if type(currentValue) ~= type(defaultValue) then
				animateParams[key] = defaultValue
			end
		end

		controllerTable.AnimateParams = animateParams
	else
		controllerTable.AnimateParams = table.clone(fillInAnimateParams)
	end

	return setmetatable(controllerTable :: TableContent, controller)
end

function controller.ChangeAllAnimations(self: AnimateController, newAnimations: Instance | Animations): ()
	self.Animations = typeof(newAnimations) == "Instance" and FolderToAnimations(newAnimations)
		or DeepClone(newAnimations)

	if self.IsLoaded then
		for name, anim in self.Animations do
			self:RegisterAnimation(name, anim, true)
		end

		self.Reload = true
	end
end

function controller.ChangeAnimation(self: AnimateController, animName: AnimationName, new: Instance | { Animation }): ()
	self.Animations[animName] = typeof(new) == "Instance" and (new:IsA("Animation") and new or new:GetChildren()) or new

	if self.IsLoaded then
		self:RegisterAnimation(animName, self.Animations[animName], true)
		self.Reload = true
	end
end

function controller.ResetToDefaultAnimations(self: AnimateController): ()
	self.Animations = DeepClone(self.DefaultAnimations)

	if self.IsLoaded then
		for name, anim in self.Animations do
			self:RegisterAnimation(name, anim, true)
		end

		self.Reload = true
	end
end

function controller.ChangeAnimateParams(self: AnimateController, newParams: AnimateParams)
	self.AnimateParams = newParams
end

function controller.ChangeAnimateParamValue(self: AnimateController, index: keyof<AnimateParams>, value: any): ()
	self.AnimateParams[index] = value
end

function controller.GetRegister(self: AnimateController, animName: string): AnimationRegisterGroup?
	return self.AnimationRegisters[animName]
end

function controller.RegisterAnimation(
	self: AnimateController,
	indexName: string,
	reference: Animations | { Animation },
	override: boolean?
): ()
	if not override and self:GetRegister(indexName) then
		warn(`Animation "{indexName}" is already registered.`)
		return
	end

	local function Load(animation: Animation)
		local track = self.Animator:LoadAnimation(animation)
		local looped = track:GetAttribute("Looped")
		local weight = animation:GetAttribute("Weight") or 1

		if looped ~= nil then
			track.Looped = looped
		end

		self.AnimationRegisters[indexName].TotalWeight += weight
		table.insert(self.AnimationRegisters[indexName].Animations, {
			Animation = animation,
			AnimationTrack = track,
			Weight = weight,
		})
	end

	self.AnimationRegisters[indexName] = {
		TotalWeight = 0,
		Animations = {},
	}

	if typeof(reference) == "Instance" then
		Load(reference :: Animation)
	else
		for _, animation in ipairs(reference) do
			Load(animation)
		end
	end
end

function controller.Load(self: AnimateController): ()
	if self.IsLoaded then
		return
	end

	self.IsLoaded = true

	local character: Model = self.Character
	local rootPart = self.RootPart
	local humanoid = self.Humanoid
	local animator = self.Animator

	local currentMainAnimName: string?
	local currentMainTrack: AnimationTrack?
	local currentMainTrackOnLooped: RBXScriptConnection?

	local currentSecondaryTracks: { [string]: AnimationTrack } = {} -- The AnimationTracks playing from PlayAnimation function

	local currentTool: Tool?
	local currentToolTrack: AnimationTrack?
	local currentToolAnims: { [string]: Animation } = {}

	-- MAIN FUNCTIONS

	local function GetRigScale(): number
		return self.AnimateParams.ApplyRigScale and self.Character:GetScale() or 1
	end

	-- REGISTERING

	for name, anim in self.Animations do
		self:RegisterAnimation(name, anim)
	end

	-- Plays an animation independently of the current main animation state.
	-- This will not be overriden.
	-- It has higher animation priority than the main animations, but it doesn't stop them from playing.
	local function PlayAnimation(
		animName: string,
		playParams: PlayAnimationParams,
		referenceOverride: string?
	): AnimationTrack
		local register = self:GetRegister(animName)

		if not register then
			warn(`Attempt to play unregistered animation: {animName}.`)
			return
		end

		local animTrack = GetAnimationTrack(register)
		local indexName = referenceOverride or animName

		if currentSecondaryTracks[indexName] and currentSecondaryTracks[indexName].Animation == animTrack.Animation then
			return currentSecondaryTracks[indexName]
		end

		playParams = playParams or {} :: PlayAnimationParams
		currentSecondaryTracks[indexName] = animTrack

		animTrack.Priority = playParams.Priority or Enum.AnimationPriority.Movement
		-- Must be at least 2 values higher than Core to avoid mixing.
		animTrack:Play(
			playParams.FadeTime,
			playParams.Weight,
			playParams.Speed or (playParams.Duration and animTrack.Length / playParams.Duration) or nil
		)
		animTrack.Stopped:Once(function()
			currentSecondaryTracks[indexName] = nil
		end)

		return animTrack
	end

	local function SwitchAnimation(animName: string, playParams: PlayAnimationParams, ignoreName: boolean?): ()
		local register = self:GetRegister(animName)

		if not register then
			warn(`Attempt to play unregistered animation: {animName}.`)
			return
		end

		local animTrack = GetAnimationTrack(register)

		local function Switch()
			if currentMainTrack then
				currentMainTrack:Stop(playParams.FadeTime)
				currentMainTrack = nil
			end

			animTrack.Priority = playParams.Priority or Enum.AnimationPriority.Core
			animTrack:Play(
				playParams.FadeTime,
				playParams.Weight,
				playParams.Speed or (playParams.Duration and animTrack.Length / playParams.Duration) or nil
			)

			if animTrack.Looped then
				currentMainTrackOnLooped = animTrack.DidLoop:Connect(function()
					SwitchAnimation(animName, playParams, true)
					-- Handles switching between animations under the same animations folder.
				end)

				animTrack.Stopped:Once(function()
					if currentMainTrackOnLooped then
						currentMainTrackOnLooped:Disconnect()
					end
				end)
			end

			currentMainAnimName = animName
			currentMainTrack = animTrack
		end

		if currentMainTrack then
			if
				not ignoreName and currentMainAnimName ~= animName
				or ignoreName and currentMainTrack.Animation ~= animTrack.Animation
			then
				Switch()
				return
			end

			currentMainTrack:AdjustSpeed(
				playParams.Speed
					or (playParams.Duration and animTrack.Length / playParams.Duration)
					or currentMainTrack.Speed
			)
			currentMainTrack:AdjustWeight(playParams.Weight or currentMainTrack.WeightTarget)
			currentMainTrack.Priority = playParams.Priority or currentMainTrack.Priority

			return
		end

		Switch()
	end

	-- TOOL FUNCTIONS

	local function GetTool(): Tool?
		return character:FindFirstChildOfClass("Tool")
	end

	local function GetToolAnims(tool: Tool): { [string]: Animation }
		local animations = {
			Holding = tool:FindFirstChild("ToolHolding"),
			Idle = tool:FindFirstChild("ToolIdle"),
			Walk = tool:FindFirstChild("ToolWalk"),
			Run = tool:FindFirstChild("ToolRun"),
			Sprint = tool:FindFirstChild("ToolSprint"),
		}

		for i, obj in animations do
			if not obj then
				animations[i] = nil
			elseif obj:IsA("Animation") then
				continue
			elseif obj:IsA("ObjectValue") and obj.Value and obj.Value:IsA("Animation") then
				animations[i] = obj.Value
			else
				animations[i] = nil
			end
		end

		return animations :: { [string]: Animation }
	end

	-- STATE HANDLERS

	local stateFunctions = {}

	local function GetPossibleVariant(defaultAnimName: string): string
		if not currentTool or not self:GetRegister(currentTool.Name .. defaultAnimName) then
			return defaultAnimName
		end

		return currentTool.Name .. defaultAnimName
	end
	stateFunctions.Running = function()
		local velocity = rootPart.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude / GetRigScale()

		local sprintVariant = GetPossibleVariant("Sprint")
		local runVariant = GetPossibleVariant("Run")

		if horizontalSpeed >= self.AnimateParams.SprintDetectSpeed and self:GetRegister(sprintVariant) then
			SwitchAnimation(sprintVariant, {
				FadeTime = 0.3,
				Speed = horizontalSpeed / self.AnimateParams.SprintSpeedDividend,
			}, self.Reload)
		elseif horizontalSpeed >= self.AnimateParams.RunDetectSpeed and self:GetRegister(runVariant) then
			SwitchAnimation(runVariant, {
				FadeTime = 0.3,
				Speed = horizontalSpeed / self.AnimateParams.RunSpeedDividend,
			}, self.Reload)
		elseif horizontalSpeed > 0.5 then -- Also raised threshold slightly
			SwitchAnimation(GetPossibleVariant("Walk"), {
				FadeTime = 0.2,
				Speed = horizontalSpeed / self.AnimateParams.WalkSpeedDividend,
			}, self.Reload)
		else
			SwitchAnimation(GetPossibleVariant("Idle"), {
				FadeTime = 0.1,
			}, self.Reload)
		end
	end

	stateFunctions.Jumping = function()
		PlayAnimation(
			"Jump",
			{ FadeTime = 0.1, Duration = self.AnimateParams.JumpDuration, Priority = Enum.AnimationPriority.Movement }
		)
	end

	stateFunctions.Climbing = function()
		local speed = rootPart.AssemblyLinearVelocity.Magnitude / GetRigScale()
		SwitchAnimation("Climb", { FadeTime = 0.1, Speed = speed / self.AnimateParams.ClimbSpeedDividend }, self.Reload)
	end

	stateFunctions.Swimming = function()
		local speed = rootPart.AssemblyLinearVelocity.Magnitude / GetRigScale()

		if speed < 5 and self:GetRegister("SwimIdle") then
			SwitchAnimation("SwimIdle", { FadeTime = 0.2 })
		else
			if self:GetRegister("Swim") then
				SwitchAnimation(
					"Swim",
					{ FadeTime = 0.3, Speed = speed / self.AnimateParams.SwimSpeedDividend },
					self.Reload
				)
			end
		end
	end

	stateFunctions.Landed = function()
		local speed = math.abs(rootPart.AssemblyLinearVelocity.Y / GetRigScale())

		if speed >= 125 and self:GetRegister("LandedRoll") then
			PlayAnimation("LandedRoll", { FadeTime = 0.2, Duration = self.AnimateParams.LandedDuration }, self.Reload)
		elseif speed >= 75 and self:GetRegister("Landed") then
			PlayAnimation("Landed", { FadeTime = 0.2, Duration = self.AnimateParams.LandedDuration }, self.Reload)
		end
	end

	stateFunctions.Seated = function()
		SwitchAnimation("Sit", { FadeTime = 0.5 }, self.Reload)
	end

	stateFunctions.Freefall = function()
		SwitchAnimation("Fall", { FadeTime = 0.1 }, self.Reload)
	end

	local function StopAllAnimations(): ()
		for _, track in currentSecondaryTracks do
			track:Stop()
		end

		if currentMainTrack then
			currentMainTrack:Stop()
			currentMainTrack = nil
		end
	end

	stateFunctions.Died = StopAllAnimations
	stateFunctions.GettingUp = StopAllAnimations
	stateFunctions.FallingDown = StopAllAnimations
	stateFunctions.PlatformStanding = StopAllAnimations
	stateFunctions.Physics = StopAllAnimations

	local function UpdateTool()
		local tool = GetTool()
		local toolAnims = tool and GetToolAnims(tool)

		currentTool = tool

		local function StopCurrentHolding()
			local currentHoldingTrack = currentSecondaryTracks.ToolHolding

			if currentHoldingTrack then
				currentHoldingTrack:Stop(0.2)
			end
		end

		if tool and toolAnims then
			local newAnims = {}

			for i, anim in toolAnims do
				local setName = tool.Name .. i

				if not self:GetRegister(setName) then
					self:RegisterAnimation(setName, anim)
				end

				newAnims[setName] = anim
			end

			currentToolAnims = newAnims

			if toolAnims.Holding or tool:FindFirstChild("Handle") then
				local setName = tool.Name .. "Holding"

				if toolAnims.Holding and not self:GetRegister(setName) then
					self:RegisterAnimation(setName, toolAnims.Holding)
				end

				StopCurrentHolding()
				PlayAnimation(toolAnims.Holding and setName or "ToolHolding", {
					FadeTime = 0.2,
				}, "ToolHolding")
			else
				StopCurrentHolding()
			end
		else
			StopCurrentHolding()
		end
	end

	local function UpdateState(): ()
		local newState = humanoid:GetState()
		local enteredFunction = stateFunctions[newState.Name]

		if enteredFunction then
			task.spawn(enteredFunction)
		end

		-- Calls on entered regardless to update animations' speeds and other properties.
		-- Essential for updating climbing, swimming, walking, and running animations' speeds.

		if self.Reload then
			self.Reload = nil
		end
	end

	local function Evaluate(): ()
		-- In case there aren't tool animations anymore, it is important to update idle, running, and others to their defaults.
		UpdateTool()
		UpdateState()
	end

	task.spawn(Evaluate)
	table.insert(self.Connections, character.ChildAdded:Connect(Evaluate))
	table.insert(self.Connections, character.ChildRemoved:Connect(Evaluate))
	table.insert(self.Connections, humanoid.StateChanged:Connect(UpdateState))

	do
		local totalTime = 0

		table.insert(
			self.Connections,
			runService.RenderStepped:Connect(function(dt)
				totalTime += dt

				if totalTime < 0.1 then
					return
				end

				totalTime = 0
				UpdateState()
			end)
		)
	end
end

function controller.Unload(self: AnimateController): ()
	if not self.IsLoaded then
		return
	end

	self.IsLoaded = false
	self.Reload = nil

	for _, group in self.AnimationRegisters do
		for _, register in ipairs(group.Animations) do
			register.AnimationTrack:Stop(0)
			register.AnimationTrack:Destroy()
		end
	end

	for _, connection in self.Connections do
		connection:Disconnect()
	end

	table.clear(self.Connections)
	table.clear(self.AnimationRegisters)
end

return constructor
