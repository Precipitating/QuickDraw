local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RandomModule = require(ReplicatedStorage.Shared.Utility.RandomModule)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local ServerEffectsDisplayer = require(ServerScriptService.Server.Classes.Environment.ServerEffectsDisplayer)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
type Human = ClassTypes.Human
type HumanPlayer = ClassTypes.HumanPlayer
type HumanNPC = ClassTypes.HumanNPC

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

local function ApplyDamageHighlight(humanClass: Human, limbName: string)
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = humanClass.BodyParts[limbName]
	Debris:AddItem(highlight, 0.5)
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
end

function DamageModule:ApplyDamage(
	human: HumanPlayer | HumanNPC,
	limbName: string,
	damage: number,
	shotPos: Vector3,
	shooter: Player | Model
)
	if not human or not human.LimbHealth or not human.LimbHealth[limbName] or human.Dead or human.Invincible then
		return
	end
	local gun = human.CurrentGun

	if gun then
		local reloading = gun.Reloading

		-- stop reloading if hurt
		if reloading then
			gun:StopReloading()
		end
	end

	if human.HumanType == "NPC" then
		human = human :: HumanNPC
		local ai = human.AI

		-- if npc damaged on patrol, seek immediately the target
		-- only applies to SHOT damage type
		if ai and ai.StateMachine:GetState() == "Patrol" and shotPos then
			ai.StateMachine:Transition("Seek", {
				Target = if shooter:IsA("Player") then shooter.Character else shooter,
			})
		end
	elseif human.HumanType == "Player" then
		human = human :: HumanPlayer
		human:AdjustGrayscale()
	end

	local multiplier = LimbDamageMultiplier[limbName] or 1

	if not human or human.Dead or not human.OnHit then
		return
	end

	human:OnHit(damage, multiplier, limbName, shooter)

	ApplyDamageHighlight(human, limbName)
end

function DamageModule:ApplyInflictingDamage(inflictingDamageData: ClassTypes.InflictingDamage)
	local spreadParticleName = inflictingDamageData.SpreadParticleName
	local damagedLimb = inflictingDamageData.LimbHit
	local spreadDuration = inflictingDamageData.SpreadDuration

	if spreadParticleName then
		ServerEffectsDisplayer:DisplaySpreadParticle(spreadParticleName, spreadDuration, damagedLimb)
	end

	task.spawn(function()
		for _ = 1, spreadDuration do
			self.DamageHuman(inflictingDamageData)
			task.wait(1)
		end
	end)
end

local function HandleLimbDestroyed(humanClass: Human, limbName: string, damage: number)
	if not humanClass or not humanClass.LimbHealth or not humanClass.LimbHealth[limbName] then
		return
	end

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

function DamageModule.DamageHuman(damageData: ClassTypes.InflictingDamage | ClassTypes.GunShotDamage)
	local hitObj = if damageData.Type == "Inflict" then damageData.LimbHit else damageData.RaycastResult
	local human = damageData.TargetHuman
	if not human then
		return
	end
	if human.Invincible then
		warn("invicible, cant hit")
		return
	end
	local limbHealth = human.LimbHealth
	local damage = damageData.Damage
	local shooter = damageData.Shooter
	local shotPos = if damageData.Type == "Shot" then damageData.ShotPosition else nil

	if not hitObj then
		warn("[DamageHuman] Invalid hit object")
		return
	end
	if human.Dead or not limbHealth then
		return
	end

	local limbName = nil
	if typeof(hitObj) == "Instance" and hitObj:IsA("BasePart") then
		limbName = hitObj.Name
	elseif typeof(hitObj) == "RaycastResult" then
		limbName = hitObj.Instance.Name
	end

	if not limbHealth[limbName] then
		return
	end

	ServerSoundHandler:Play3DOneShotToOthers(
		nil,
		"BulletHitGroan",
		human.HRP,
		{ Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) }
	)
	DamageModule:ApplyDamage(human, limbName, damage, shotPos, shooter)

	if limbHealth[limbName] <= 0 then
		HandleLimbDestroyed(human, limbName, damage)
	end

	if not human or not human.Health then
		return
	end
	if human.Health <= 0 then
		human:Die(shooter)
	end

	if typeof(hitObj) == "RaycastResult" then
		ServerEffectsDisplayer:DisplayBloodHit(hitObj.Position, hitObj.Normal)
	end
end

return DamageModule
