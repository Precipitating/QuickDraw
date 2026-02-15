local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

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

function DamageModule.DamageHuman(hitObj: Instance?, playerHumanoid: Humanoid?, damageInflicted: number)
	if not hitObj then
		warn("[GunSignals.PlayerHit] Hit object reference invalid or not a mesh part")
		return
	end

	if not playerHumanoid then
		warn("[GunSignals.PlayerHit] playerHumanoid  reference invalid")
		return
	end

	local humanClass: Human = PlayerManager:GetHumanClass(playerHumanoid)
	local limbName = hitObj.Name
	local limbHit = humanClass.LimbHealth and humanClass.LimbHealth[limbName] or nil
	if not humanClass.LimbHealth then
		error("limbhealth is nil")
		return
	end
	if not limbHit then
		warn("Didn't hit a limb")
		return
	end

	local limbDamageApplied = damageInflicted
	local multiplierDamage = damageInflicted * (LimbDamageMultiplier[limbName] or 1)

	-- dmg
	humanClass.LimbHealth[limbName] -= limbDamageApplied
	humanClass.Health -= multiplierDamage
	print(
		`{limbName} hit! {limbDamageApplied} damage applied!, current limb health = {humanClass.LimbHealth[limbName]}, core hp = {humanClass.Health}`
	)

	-- head or torso being 0 limb health means insta death
	if humanClass.LimbHealth[limbName] <= 0 then
		humanClass:DisableLimb(limbName)
		if limbName == "Head" or limbName == "UpperTorso" or limbName == "LowerTorso" then
			humanClass.Health = 0
		else
			-- if blacked out already, apply damage to all limbs
			task.spawn(function()
				for _, limbHealth in pairs(humanClass.LimbHealth) do
					limbHealth -= limbDamageApplied
				end
			end)
		end
	end

	if humanClass.Health <= 0 then
		print("Should be dead")
		humanClass:OnDeath()
		return
	end
end

return DamageModule
