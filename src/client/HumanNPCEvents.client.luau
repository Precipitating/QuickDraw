-- Sync NPC data from server, so client handles the NPC visuals
-- NPC position is handled by server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundManager = require(ReplicatedStorage.Shared.Classes.SoundManager)
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local EffectsDisplayer = require(script.Parent.VisualEffectsHandler.EffectsDisplayer)
local clientNpcModule = require(script.Parent.LightweightNpcsClient.Code.LightweightNpcsClientModule)
local ClientNpcTypes = require(ReplicatedStorage.Shared.NPCData.NPCs.LightweightNPCData.ClientNpcTypes)
local CommonNPCData = require(ReplicatedStorage.Shared.NPCData.NPCs.CommonNPCData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local BloodFlowEmitter = ReplicatedStorage.Shared.Templates.BloodFlow

local function RagdollNPC(model: Model?, enabled: boolean)
	if not model then
		return
	end
	local humanoid: Humanoid? = model:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	local isDead = humanoid:GetState() == Enum.HumanoidStateType.Dead
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, if enabled then true else false)

	for _, part in model:GetDescendants() do
		if part:IsA("AnimationConstraint") then
			part.Enabled = not enabled
		elseif part:IsA("BallSocketConstraint") and isDead then
			part.MaxFrictionTorque = 10
		end

		if part:IsA("MeshPart") and part.CanCollide == false then
			part.CanCollide = enabled
		elseif part.Name == "HumanoidRootPart" then
			part.Anchored = enabled
		end
	end
end

local function SetupNPCRagdoll(npcRecord: ClientNpcTypes.clientNpcRecordType)
	if not npcRecord or not npcRecord.instance then
		return
	end
	local model = npcRecord.instance
	if not model then
		warn("NPC ragdoll cannot be set up on client, missing model")
		return
	end

	local humanoid = model:WaitForChild("Humanoid", 3)

	if not humanoid then
		warn("NPC ragdoll cannot be set up on client, missing humanoid")
		return
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	humanoid.StateChanged:Connect(function(previous: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Physics then
			RagdollNPC(model, true)
			return
		end
		if previous == Enum.HumanoidStateType.Physics then
			RagdollNPC(model, false)
			return
		end
	end)
end

local function StoreBodyParts(npcRecord: ClientNpcTypes.clientNpcRecordType)
	if not npcRecord or not npcRecord.instance then
		Utility.Warn("[StoreBodyParts] Missing character/NPC record")
		return
	end
	local character = npcRecord.instance

	for _, part in character:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end

		npcRecord.bodyParts[LimbsEnum[part.Name]] = part
	end
end

local function SetNPCDead(character: Model?)
	if not character then
		warn("[SetupNPCDeath] NPC missing model")
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 3) :: Humanoid?

	if not humanoid then
		warn("[SetupNPCDeath] NPC missing humanoid")
		return
	end

	character:AddTag("Dead")

	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		part.CollisionGroup = "Dead"
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	if character.PrimaryPart then
		character.PrimaryPart.Anchored = false
	end
end

local function ApplyDamageHighlight(part: BasePart)
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.Parent = part
	task.delay(0.5, function()
		highlight:Destroy()
	end)
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
end

local function ToggleInvincibleHighlight(parent: Model?, state: boolean)
	local highlight = parent and parent:FindFirstChildOfClass("Highlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "InvincibilityHighlight"
		highlight.OutlineTransparency = 1
		highlight.FillColor = Color3.fromRGB(1, 170, 255)
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = parent
	end

	if state then
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end

local function HitLimb(
	npcRecord: ClientNpcTypes.clientNpcRecordType,
	limbHit: number,
	shotPos: Vector3,
	shotPosNormal: Vector3
)
	-- convert to string
	limbHit = LimbsEnum[limbHit]

	if shotPos and shotPosNormal then
		EffectsDisplayer:DisplayBloodHit(shotPos, shotPosNormal)
	end

	if not limbHit then
		debug.traceback("Missing string for hit limb", 5)
		return
	end

	local model = npcRecord.instance
	if not model then
		warn("Missing npc model for hit limb")
		return
	end

	local limb = model:FindFirstChild(limbHit)

	if not limb then
		warn("Missing npc limb reference for hit limb")
		return
	end
	ApplyDamageHighlight(limb)
end

local function SetupBloodEmitters(npcRecords: ClientNpcTypes.clientNpcRecordType)
	local model = npcRecords.instance
	if not model then
		Utility.Warn("Failed to get BloodEmitters reference")
		return
	end

	local upperTorso = Utility.GetInstance(model, true, "UpperTorso")
	local lowerTorso = Utility.GetInstance(model, true, "LowerTorso")

	if not upperTorso or not lowerTorso then
		error("[SetupBloodEmitters] Failed to get torso references")
	end

	-- legs
	for limbId, attachmentName in CommonNPCData.DISMEMBER_ATTACHMENTS do
		local attachment = if lowerTorso:FindFirstChild(attachmentName)
			then lowerTorso:FindFirstChild(attachmentName)
			else upperTorso:FindFirstChild(attachmentName)
		if not attachment then
			warn("Attachment not found")
			continue
		end
		local bloodEmitter: ParticleEmitter = BloodFlowEmitter:Clone()
		local isLeg = limbId == LimbsEnum.LeftUpperLeg
			or LimbsEnum.LeftLowerLeg
			or LimbsEnum.RightUpperLeg
			or LimbsEnum.RightLowerLeg
		local isHead = limbId == LimbsEnum.Head
		local isArm = limbId == LimbsEnum.LeftUpperArm
			or LimbsEnum.LeftLowerArm
			or LimbsEnum.RightUpperArm
			or LimbsEnum.RightLowerArm

		if isLeg then
			bloodEmitter.EmissionDirection = Enum.NormalId.Bottom
		-- arm
		elseif isArm then
			bloodEmitter.EmissionDirection = if isArm == LimbsEnum.LeftUpperArm
				then Enum.NormalId.Left
				else Enum.NormalId.Right
		elseif isHead then
			bloodEmitter.EmissionDirection = Enum.NormalId.Top
		end

		npcRecords.bloodEmitterRefs[limbId] = bloodEmitter
		bloodEmitter.Enabled = false
		bloodEmitter.Parent = attachment
	end
end
--------------------------------------------------------------------------------------------------------------------
local StateEvents = {
	Initialize = function(npcRecord: ClientNpcTypes.clientNpcRecordType)
		StoreBodyParts(npcRecord)
		SetupNPCRagdoll(npcRecord)
		SetupBloodEmitters(npcRecord)
	end,

	Dead = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		local attacker = event.attacker
		local character = npcRecord.instance
		if not character then
			return
		end
		SetNPCDead(character)
		npcRecord.isDead = true
	end,

	InvincibleToggle = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		ToggleInvincibleHighlight(npcRecord.instance, event.state)
	end,

	SpreadParticle = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		local particleName = event.ParticleName
		local duration = event.Duration
		-- num -> string
		local limbName = LimbsEnum[event.limbName]
		local npcCharacter = npcRecord.instance

		if not npcCharacter then
			Utility.Warn(`SpreadParticle NPC client event failed, npc model missing`)
			return
		end

		EffectsDisplayer:DisplaySpreadParticleClient(particleName, duration, npcCharacter:FindFirstChild(limbName))
	end,

	LimbHit = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		if npcRecord.isDead then
			return
		end

		local limbHit = event.limb
		local shotPos = event.position
		local shotPosNormal = event.normal

		if not limbHit then
			return
		end
		HitLimb(npcRecord, limbHit, shotPos, shotPosNormal)
	end,

	HealAll = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		for limbId, part in npcRecord.bodyParts do
			part.Transparency = 0
			part.CanCollide = true
			part.CanQuery = true
			part.CanTouch = true

			---------------------------------------------------------------------------------------------------------
			local hasConstraint: AnimationConstraint? = part:FindFirstChildOfClass("AnimationConstraint")
			local hasBallSocket: BallSocketConstraint? = part:FindFirstChildOfClass("BallSocketConstraint")
			local isBleeding: ParticleEmitter? = npcRecord.bloodEmitterRefs
				and npcRecord.bloodEmitterRefs[limbId] :: ParticleEmitter?

			---------------------------------------------------------------------------------------------------------
			if hasConstraint then
				hasConstraint.Enabled = true
			end

			if hasBallSocket then
				hasBallSocket.LimitsEnabled = true
				hasBallSocket.MaxFrictionTorque = CommonNPCData.BALL_SOCKET_MAX_FRICTION_TORQUES[limbId]
			end

			if isBleeding then
				isBleeding.Enabled = false
			end
		end
	end,

	DismemberLimb = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		local partToDismember: number = event.limb

		if not partToDismember then
			Utility.Warn("Cannot dismember part on client, missing limb number ref")
			return
		end

		local shouldBleed = CommonNPCData.DISMEMBER_ATTACHMENTS[partToDismember]
		local bodyPart: BasePart = npcRecord.bodyParts[partToDismember] :: BasePart

		if not bodyPart then
			Utility.Warn("Cannot dismember part on client, missing limb  ref")
			return
		end

		-- 1. If part dismembered can bleed, enable its particle.
		if shouldBleed then
			local bloodLeakParticle: ParticleEmitter? = npcRecord.bloodEmitterRefs
				and npcRecord.bloodEmitterRefs[partToDismember] :: ParticleEmitter?
			if not bloodLeakParticle then
				Utility.Warn("Cannot get particle to bleed out a dismembered limb")
				return
			end
			bloodLeakParticle.Enabled = true
		end

		-- 2. Hide all affected limbs, unless its the head which guarantees death
		if partToDismember == LimbsEnum.Head then
			bodyPart:Destroy()
			return
		end
		--
		bodyPart.Transparency = 0.5
		bodyPart.CanCollide = false
		bodyPart.CanQuery = false

		-- 2.1 Also hide chained limbs
		local hasChain = CommonNPCData.LIMB_CHAIN[partToDismember]
		if hasChain then
			for _, partID in hasChain do
				local limbRef: BasePart = npcRecord.bodyParts[partID] :: BasePart

				if limbRef then
					limbRef.Transparency = 1
					limbRef.CanCollide = false
					limbRef.CanQuery = false
				end
			end
		end
	end,

	DisableLimb = function(npcRecord: ClientNpcTypes.clientNpcRecordType, event: any, serverTime: number)
		local partToDisable: number = event.limb

		if not partToDisable then
			Utility.Warn("Cannot disable part on client, missing limb number ref")
			return
		end

		local limbRef: BasePart = npcRecord.bodyParts[partToDisable] :: BasePart

		if not limbRef then
			Utility.Warn("Missing limb reference disabling limb on client!")
			return
		end
		local animationConstraint: AnimationConstraint? = limbRef:FindFirstChildOfClass("AnimationConstraint")
		local ballSocketConstraint: BallSocketConstraint? = limbRef:FindFirstChildOfClass("BallSocketConstraint")

		if not animationConstraint or not ballSocketConstraint then
			Utility.Warn("Missing animation/ballSocket constraint disabling limb on client!")
			return
		end

		animationConstraint.Enabled = false
		ballSocketConstraint.LimitsEnabled = false
		ballSocketConstraint.MaxFrictionTorque = 0

		-- Chain disable
		local hasChain = CommonNPCData.LIMB_CHAIN[partToDisable]
		if hasChain then
			for _, partID in hasChain do
				local childLimb: BasePart = npcRecord.bodyParts[partID] :: BasePart
				local childAnimationConstraint: AnimationConstraint? =
					childLimb:FindFirstChildOfClass("AnimationConstraint")
				local childBallSocketConstraint: BallSocketConstraint? =
					childLimb:FindFirstChildOfClass("BallSocketConstraint")

				if childAnimationConstraint and childBallSocketConstraint then
					childAnimationConstraint.Enabled = false
					childBallSocketConstraint.LimitsEnabled = false
					childBallSocketConstraint.MaxFrictionTorque = 0
				end
			end
		end
	end,
}

clientNpcModule.onNpcLoad:Connect(function(npcRecord: ClientNpcTypes.clientNpcRecordType)
	npcRecord.onCustomEvent:Connect(function(event: any, serverTime: number)
		StateEvents[event.id](npcRecord, event, serverTime)
	end)
end)
