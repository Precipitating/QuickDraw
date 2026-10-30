local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local LightweightNpcsServerAPI = require(ServerScriptService.Server.LightweightNpcs.LightweightNpcsServerAPI)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local Networker = require(ReplicatedStorage.Packages.Networker).server

local ACTION_COST = {
	Jump = HumanConstants.JUMP_DRAIN,
	Roll = HumanConstants.ROLL_DRAIN,
	Kick = HumanConstants.KICK_DRAIN,
}
local BARGE_BOX_SIZE = Vector3.new(4, 4, 3)
local BARGE_OFFSET = CFrame.new(0, 0, -3)
local BARGE_MAX_DURATION = 10 -- safety timeout, set to your barge length
local BARGE_LIFT = 0.25 -- fraction of force added upward so ragdolls don't just drag

local activeBarges: { [Player]: () -> () } = {}
local Inputs = {}

-- Shared guards for grounded leg actions. Returns the human class if allowed.
local function GetGroundedHuman(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or not humanClass.Humanoid then
		return nil
	end
	if humanClass:IsLegless() then
		return nil
	end
	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return nil
	end
	return humanClass
end

function Inputs:ApplyJumpDrain(player: Player)
	local humanClass = GetGroundedHuman(player)
	if not humanClass then
		return false
	end
	return humanClass.Stamina:TryConsume(ACTION_COST.Jump)
end

function Inputs:BindHumanStamina(player: Player, humanClass)
	humanClass.Janitor:Add(humanClass.Stamina.OnDepleted:Connect(function()
		if humanClass.Humanoid and humanClass.Humanoid.Health > 0 then
			self:ToggleSprint(player, false)
			self.networker:fire(player, "StaminaDepleted")
		end
	end))
end

function Inputs:ApplyRollDrain(player: Player, lookDir: Vector3)
	assert(lookDir, "Missing lookDir from client to roll!")
	local humanClass = GetGroundedHuman(player)
	if not humanClass then
		return false
	end
	if not humanClass.Stamina:TryConsume(ACTION_COST.Roll) then
		return false
	end
	humanClass:ApplyRollForce(lookDir)
	return true
end
function Inputs:ApplyKickDrain(player: Player)
	local humanClass = GetGroundedHuman(player)
	if not humanClass then
		return false
	end
	if not humanClass.Stamina:TryConsume(ACTION_COST.Kick) then
		return false
	end
	humanClass:ApplyKickForce()
	return true
end
function Inputs:ToggleSprint(player: Player, active: boolean, bypassMovingRequirement: boolean?)
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or not humanClass.Stamina then
		return
	end

	humanClass:ToggleSprinting(active, bypassMovingRequirement)

	if humanClass.Stamina.Current <= 0 then
		self.networker:fire(player, "StaminaDepleted")
	end
end

function Inputs:CanBarge(player: Player)
	if not player then
		return false
	end
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or not humanClass.Stamina then
		return false
	end
	local stamina = humanClass.Stamina.Current

	if humanClass.Character and humanClass.Character:FindFirstChildOfClass("Tool") then
		PopupGUI:NewPopup(player, 2, "You're holding something, unequip to barge")
		return false
	end
	if humanClass:IsLegless() then
		PopupGUI:NewPopup(player, 2, "You have no legs to barge!")
		return false
	end
	if stamina <= 0 then
		PopupGUI:NewPopup(player, 2, "Not enough stamina to barge!")
		return false
	end

	return true
end

-- Walks up from any hit part to a player human class or lightweight NPC.
local function FindTarget(hitPart: BasePart)
	local inst = hitPart.Parent
	while inst and inst ~= workspace do
		local npcId = inst:GetAttribute("npcId")
		if npcId then
			local npc = LightweightNpcsServerAPI:GetNpcById(npcId)
			if npc then
				return npc, "NPC"
			end
		end
		local humanoid = inst:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local humanClass = PlayerManager:GetHumanClass(humanoid)
			if humanClass then
				return humanClass, "Player"
			end
		end
		inst = inst.Parent
	end
	return nil, nil
end

local function GetPushDir(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	local dir = flat.Unit * HumanConstants.BARGE_FORCE
	return dir + Vector3.new(0, HumanConstants.BARGE_FORCE * BARGE_LIFT, 0)
end

local function KnockbackPlayer(humanClass, dir: Vector3)
	humanClass:Ragdoll(5)
	task.defer(function()
		-- if the target is client-owned, move this impulse to a remote on their client
		humanClass:ApplyImpulse(dir * humanClass.HRP.AssemblyMass)
	end)
end

function Inputs:AddBargeCollision(player: Player)
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		Utility.Warn("Cannot initialize barge, player/character/HRP missing")
		return
	end

	self:DestroyBargeCollision(player) -- never stack barges

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local startTime = os.clock()
	local conn: RBXScriptConnection?

	local function Stop(reason: string?)
		if not conn then
			return
		end
		conn:Disconnect()
		conn = nil
		activeBarges[player] = nil
		if reason then
			self.networker:fire(player, "StopBarge", reason)
		end
	end
	activeBarges[player] = Stop

	conn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent or os.clock() - startTime > BARGE_MAX_DURATION then
			Stop("Timeout")
			return
		end

		local parts = workspace:GetPartBoundsInBox(hrp.CFrame * BARGE_OFFSET, BARGE_BOX_SIZE, params)
		if #parts == 0 then
			return
		end

		-- entities take priority over walls, regardless of part order
		local target, kind, hitPart
		local hitWall = false
		for _, part in parts do
			local t, k = FindTarget(part)
			if t then
				target, kind, hitPart = t, k, part
				break
			end
			if part.CanCollide then
				hitWall = true
			end
		end

		if target then
			Stop(kind) -- "Player" or "NPC"; swap back to "Human" if the client expects it

			local targetHrp = target.HRP or target.hrp
			local dir = GetPushDir(hrp.Position, targetHrp.Position, hrp.CFrame.LookVector)

			local data = {
				Type = "Barge",
				Damage = HumanConstants.BARGE_DAMAGE,
				LimbHit = hitPart,
				TargetHuman = target,
				CanAffectShooter = false,
				Shooter = player,
			} :: ClassTypes.BargeDamage

			if kind == "Player" then
				KnockbackPlayer(target, dir)
				DamageModule.DamageHuman(data)
			else
				target.onHit:Fire(data)
				target.onImpulse:Fire(dir * 5)
				target.onRagdoll:Fire(5)
			end
		elseif hitWall then
			Stop("Environment")
			local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
			if humanClass then
				DamageModule.DamageHuman({
					Type = "Barge",
					Damage = HumanConstants.BARGE_DAMAGE,
					LimbHit = character:FindFirstChild("UpperTorso"),
					TargetHuman = humanClass,
					CanAffectShooter = true,
					Shooter = player,
				} :: ClassTypes.BargeDamage)
			end
		end
	end)
end

function Inputs:DestroyBargeCollision(player: Player)
	local stop = player and activeBarges[player]
	if stop then
		stop() -- no reason, so no StopBarge fired back at the client
	end
end
Inputs.networker = Networker.new("InputNetwork", Inputs, {
	Inputs.ToggleSprint,
	Inputs.ApplyJumpDrain,
	Inputs.ApplyRollDrain,
	Inputs.ApplyKickDrain,
	Inputs.CanBarge,
	Inputs.AddBargeCollision,
	Inputs.DestroyBargeCollision,
})
return Inputs
