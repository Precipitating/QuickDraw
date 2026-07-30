local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)

local Networker = require(ReplicatedStorage.Packages.Networker).server
local Inputs = {}

function Inputs:ApplyJumpDrain(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	local humanoid = humanClass.Humanoid

	if not humanoid then
		warn("Missing humanoid reference to apply jump drain, probably dead")
		return false
	end
	if humanClass:IsLegless() then
		return false
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end

	if humanClass.Stamina < HumanConstants.JUMP_DRAIN then
		return false
	end
	humanClass.JumpSignalled = true
	return true
end

function Inputs:ApplyRollDrain(player: Player, lookDir: Vector3)
	assert(lookDir, "Missing lookDir from client to roll!")
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)

	if not humanClass or humanClass:IsLegless() or not humanClass.Humanoid then
		return false
	end

	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end

	if humanClass.Stamina < HumanConstants.JUMP_DRAIN then
		return false
	end
	humanClass.RollSignalled = true
	humanClass:ApplyRollForce(lookDir)
	return true
end

function Inputs:ApplyKickDrain(player: Player)
	local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or humanClass:IsLegless() or not humanClass.Humanoid then
		return false
	end

	if humanClass.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		return false
	end
	if humanClass.Stamina < HumanConstants.KICK_DRAIN then
		return false
	end

	humanClass.KickSignalled = true
	humanClass:ApplyKickForce()

	return true
end

function Inputs:ToggleSprint(player: Player, active: boolean, bypassMovingRequirement: boolean?)
	local humanClass, _ = PlayerManager:GetHumanClassFromPlayer(player)
	if not humanClass or not humanClass.Stamina then
		return
	end

	humanClass:ToggleSprinting(active, bypassMovingRequirement)

	if humanClass.Stamina <= 0 then
		self.networker:fire(self.Player, "StaminaDepleted")
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
	local stamina = humanClass.Stamina

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

function Inputs:AddBargeCollision(player: Player)
	if not player then
		warn(`Cannot initialize barge colliders, player ref missing`)
		return
	end

	local character = player.Character

	if not character then
		warn(`Cannot initialize barge colliders, character ref missing`)
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn(`Cannot initialize barge colliders, HRP missing`)
		return
	end

	local collider: Part = Instance.new("Part")
	collider.CanCollide = false
	collider.CanQuery = false
	collider.CanTouch = true
	collider.Name = "BargeCollider"
	collider.Transparency = 1
	local weld: WeldConstraint = Instance.new("WeldConstraint")
	weld.Name = "BargeWeld"
	weld.Part0 = hrp
	weld.Part1 = collider
	weld.Parent = character

	collider.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)

	collider.Parent = character

	-- Destruction will remove the connection automatically
	collider.Touched:Connect(function(hitPart: BasePart)
		if not hitPart.Parent then
			return
		end
		local parent = hitPart.Parent
		local hitPlayer = parent:FindFirstChild("Humanoid")

		-- Hit environment
		if not hitPlayer then
			local humanClass = PlayerManager:GetHumanClassFromPlayer(player)
			if not humanClass then
				return
			end

			local data = {
				Damage = HumanConstants.BARGE_DAMAGE,
				LimbHit = character:FindFirstChild("UpperTorso"),
				TargetHuman = humanClass,
				CanAffectShooter = true,
				Shooter = player,
			} :: ClassTypes.BargeDamage
			DamageModule.DamageHuman(data)
			collider:Destroy()
			weld:Destroy()
			self.networker:fire(player, "StopBarge", "Environment")

			return
		end

		-- Ignore if collider touches own player initiating barge
		if parent == character then
			return
		end

		-- Hit a player, apply impulse and ragdoll
		local humanClass = PlayerManager:GetHumanClass(hitPlayer)

		if not humanClass then
			return
		end

		-- Get barge force
		local force = HumanConstants.BARGE_FORCE
		local rawDir = (humanClass.HRP.Position - hrp.Position)
		local flattenedDir = vector.create(rawDir.X, 0, rawDir.Z)
		local pushDirection = flattenedDir.Unit
		local dir: Vector3 = pushDirection * force * humanClass.HRP.AssemblyMass

		local data = {
			Damage = HumanConstants.BARGE_DAMAGE,
			LimbHit = hitPart,
			TargetHuman = humanClass,
			CanAffectShooter = false,
			Shooter = player,
		} :: ClassTypes.BargeDamage

		if humanClass.Ragdoll then
			humanClass:Ragdoll(5)
		end
		task.defer(function()
			humanClass:ApplyImpulse(dir)
		end)
		DamageModule.DamageHuman(data)

		collider:Destroy()
		weld:Destroy()
		self.networker:fire(player, "StopBarge", "Human")
	end)
end

function Inputs:DestroyBargeCollision(player: Player)
	if not player then
		warn(`Cannot initialize barge colliders, player ref missing`)
		return
	end

	local character = player.Character

	if not character then
		warn(`Cannot remove barge colliders, character ref missing`)
		return
	end

	local hasWeld = character:FindFirstChild("BargeWeld")
	local hasCollider = character:FindFirstChild("BargeCollider")

	if hasWeld then
		hasWeld:Destroy()
	end
	if hasCollider then
		hasCollider:Destroy()
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
