local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerGunHandler = require(ServerScriptService.Server.Gun.ServerGunHandler)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)

type Human = ClassTypes.Human

local LimbDamageMultiplier = {
	Head = 2.5,
	UpperTorso = 1.05,
	LowerTorso = 1.05,

	LeftUpperArm = 0.49,
	LeftLowerArm = 0.49,
	RightUpperArm = 0.49,
	RightLowerArm = 0.49,

	LeftUpperLeg = 0.7,
	LeftLowerLeg = 0.7,
	RightUpperLeg = 0.7,
	RightLowerLeg = 0.7,
}

local DamageModule = {}
local Effects = ReplicatedStorage.Shared.Effects

local function ApplyDamageHighlight(humanClass: Human, limbName: string)
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = humanClass.BodyParts[limbName]
	Debris:AddItem(highlight, 0.5)
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
end

local function ApplyDamage(humanClass, limbName: string, damage: number, shotPos: Vector3, shooter: Player?)
	if not humanClass or not humanClass.LimbHealth or not humanClass.LimbHealth[limbName] then
		return
	end

	-- stop reloading if hurt
	if humanClass.CurrentGun.Reloading then
		humanClass.CurrentGun.Reloading = false
	end

	-- if npc damaged on patrol, seek immediately the target
	if humanClass.AI and humanClass.AI.StateMachine:GetState() == "Patrol" and shotPos then
		humanClass.AI.LastSeenTargetPosition = shotPos
		humanClass.AI.StateMachine:Transition("Seek")
	end

	local multiplier = LimbDamageMultiplier[limbName] or 1

	humanClass:OnHit(damage, multiplier, limbName, shooter)

	if humanClass.AdjustGrayscale then
		humanClass:AdjustGrayscale()
	end

	ApplyDamageHighlight(humanClass, limbName)
end

function DamageModule:ApplyInflictingDamage(
	spreadParticleName: string?,
	spreadDuration: number,
	damage: number,
	humanClass: Human,
	damagedLimb: MeshPart,
	shooter: Player?
)
	local humanoid = humanClass.Humanoid
	if spreadParticleName then
		local spreadParticle = if Effects[spreadParticleName] then Effects[spreadParticleName]:Clone() else nil

		if not spreadParticle then
			warn("[SpawnFragments] Missing spread particle reference")
			return
		end

		-- visualize the effect
		if spreadParticle then
			spreadParticle.Parent = damagedLimb
			spreadParticle:Emit(1)
			Debris:AddItem(spreadParticle, spreadDuration)
		end
	end

	task.spawn(function()
		for _ = 1, spreadDuration do
			self.DamageHuman(damagedLimb, humanoid, damage, nil, shooter)
			task.wait(1)
		end
	end)
end

local function HandleLimbDestroyed(humanClass, limbName: string, damage: number)
	if limbName ~= "UpperTorso" and limbName ~= "LowerTorso" then
		if humanClass.LimbHealth[limbName] <= -60 then
			humanClass:DestroyLimb(limbName)
			return
		end
	end

	humanClass:DisableLimb(limbName)

	-- Vital limb = instant death
	if limbName == "Head" or limbName == "UpperTorso" or limbName == "LowerTorso" then
		humanClass.Health = 0
		return
	end

	-- Blacked limb = spread damage to all limbs
	task.spawn(function()
		for name in humanClass.LimbHealth do
			humanClass.LimbHealth[name] -= damage
		end
	end)
end

function DamageModule.DamageHuman(
	hitObj: RaycastResult? | BasePart,
	playerHumanoid: Humanoid?,
	damageInflicted: number,
	shotPos: Vector3,
	shooter: Player?
)
	if not hitObj then
		warn("[DamageHuman] Invalid hit object")
		return
	end
	if not playerHumanoid then
		warn("[DamageHuman] Invalid humanoid")
		return
	end

	local humanClass = PlayerManager:GetHumanClass(playerHumanoid)

	if not humanClass then
		warn("Missing human class of hit human")
		return
	end
	if humanClass.Dead then
		return
	end

	local limbName = nil
	if typeof(hitObj) == "Instance" and hitObj:IsA("BasePart") then
		limbName = hitObj.Name
	elseif typeof(hitObj) == "RaycastResult" then
		limbName = hitObj.Instance.Name
	end

	local limbHealth = humanClass.LimbHealth

	if not limbHealth then
		return
	end
	if not limbHealth[limbName] then
		return
	end

	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		"BulletHitGroan",
		humanClass.HRP,
		{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
	)
	ApplyDamage(humanClass, limbName, damageInflicted, shotPos, shooter)

	if limbHealth[limbName] <= 0 then
		HandleLimbDestroyed(humanClass, limbName, damageInflicted)
	end

	if humanClass.Health <= 0 then
		humanClass:Die(shooter)
	end

	if typeof(hitObj) == "RaycastResult" then
		ServerGunHandler:DisplayBloodHit(hitObj.Position, hitObj.Normal)
	end
end

return DamageModule
