local clientNpcModule = require(script.Parent.Code.LightweightNpcsClientModule)
local ClientNpcTypes = require(game.ReplicatedFirst.LightweightNpcsClient.Code.ClientNpcTypes)

local function RagdollNPC(model: Model?, state: boolean)
	if not model then
		return
	end
	local humanoid: Humanoid? = model:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	local isDead = humanoid:GetState() == Enum.HumanoidStateType.Dead
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, state)

	for _, part in model:GetDescendants() do
		if part:IsA("AnimationConstraint") then
			part.Enabled = state
		elseif part:IsA("BallSocketConstraint") and isDead then
			part.MaxFrictionTorque = 10
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

	humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Physics then
			RagdollNPC(model, false)
		else
			RagdollNPC(model, true)
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

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
end
clientNpcModule.onNpcLoad:Connect(function(npcRecord: ClientNpcTypes.clientNpcRecordType)
	npcRecord.onCustomEvent:Connect(function(event: any, serverTime: number)
		if event.id == "Bump" then
			if npcRecord.instance then
				local head = npcRecord.instance:FindFirstChild("Head", true) :: BasePart
				if head then
					head.Color = Color3.new(1, 1, 1)
					task.spawn(function()
						task.wait(0.1)
						head.Color = BrickColor.Yellow().Color
					end)
				end
			end
		elseif event.id == "Death" then
			local character = npcRecord.instance
			SetNPCDead(character)

			if not character then
				return
			end
		elseif event.id == "Initialize" then
			SetupNPCRagdoll(npcRecord)
		end
	end)
end)
