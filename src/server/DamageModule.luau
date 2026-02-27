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

local function ApplyDamageHighlight(humanClass: Human, limbName: string)
	local highlight = Instance.new("Highlight")
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = humanClass.BodyParts[limbName]
	Debris:AddItem(highlight, 0.5)
	TweenService:Create(highlight, TweenInfo.new(0.5), { FillTransparency = 1 }):Play()
end

local function ApplyDamage(humanClass, limbName: string, damage: number)
	local multiplier = LimbDamageMultiplier[limbName] or 1

	humanClass.LimbHealth[limbName] -= damage
	humanClass.Health -= damage * multiplier

	ServerSoundHandler:PlaySoundTo(nil, "BulletHitGroan", { Pitch = RandomModule.GetRandomDecimalBetween(0.5, 1.5) })

	if humanClass.AdjustGrayscale then
		humanClass:AdjustGrayscale()
	end

	ApplyDamageHighlight(humanClass, limbName)
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
	for name in pairs(humanClass.LimbHealth) do
		humanClass.LimbHealth[name] -= damage
	end
end

function DamageModule.DamageHuman(hitObj: RaycastResult?, playerHumanoid: Humanoid?, damageInflicted: number)
	if not hitObj then
		warn("[DamageHuman] Invalid hit object")
		return
	end
	if not playerHumanoid then
		warn("[DamageHuman] Invalid humanoid")
		return
	end

	local humanClass = PlayerManager:GetHumanClass(playerHumanoid)
	local limbName = hitObj.Instance.Name
	local limbHealth = humanClass.LimbHealth

	if not limbHealth then
		warn("[DamageHuman] LimbHealth is nil, person shot might be dead already")
		return
	end
	if not limbHealth[limbName] then
		warn("[DamageHuman] Didn't hit a limb")
		return
	end

	ApplyDamage(humanClass, limbName, damageInflicted)

	if limbHealth[limbName] <= 0 then
		HandleLimbDestroyed(humanClass, limbName, damageInflicted)
	end

	if humanClass.Health <= 0 then
		humanClass.Humanoid.Health = 0
	end

	ServerGunHandler:DisplayBloodHit(hitObj.Position, hitObj.Normal)
end

return DamageModule
