local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local LimbsEnum = require(ReplicatedStorage.Shared.NPCData.NPCs.Enums.LimbsEnum)
local EffectsDisplayer = require(StarterPlayer.StarterPlayerScripts.Client.VisualEffectsHandler.EffectsDisplayer)
local clientNpcModule = require(ReplicatedFirst.LightweightNpcsClient.Code.LightweightNpcsClientModule)
local ClientNpcTypes = require(ReplicatedFirst.LightweightNpcsClient.Code.ClientNpcTypes)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)

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
			part.Enabled = if enabled then false else true
		elseif part:IsA("BallSocketConstraint") and isDead then
			part.MaxFrictionTorque = 10
		end

		if part:IsA("MeshPart") and part.CanCollide == false then
			part.CanCollide = enabled
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
		warn("Missing string for hit limb")
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
clientNpcModule.onNpcLoad:Connect(function(npcRecord: ClientNpcTypes.clientNpcRecordType)
	npcRecord.onCustomEvent:Connect(function(event: any, serverTime: number)
		if event.id == "Initialize" then
			SetupNPCRagdoll(npcRecord)
		elseif event.id == "Dead" then
			local attacker = event.attacker
			local character = npcRecord.instance
			if not character then
				return
			end
			SetNPCDead(character)
			npcRecord.isDead = true
		elseif event.id == "LimbHit" then
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
		elseif event.id == "ToggleInvincibility" then
			ToggleInvincibleHighlight(npcRecord.instance, event.state)
		elseif event.id == "SpreadParticle" then
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
		end
	end)
end)
