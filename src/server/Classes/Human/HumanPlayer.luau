local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data
local HumanConstants = require(ReplicatedStorage.Shared.HumanConstants)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local AwardHandler = require(ServerScriptService.Server.AwardHandler.AwardHandler)
local HumanLimbGUI = require(ServerScriptService.Server.GUI.HumanLimbGUI)
local MoneyDropHandler = require(ServerScriptService.Server.MoneyDropHandler)
local ServerData = require(ServerScriptService.Server.ServerData)
local ServerScreenEffects = require(ServerScriptService.Server.ServerScreenEffects)

local Human = require(script.Parent.Human)
local HumanSignals = require(script.Parent.HumanSignals)
local HumanPlayer = setmetatable({}, Human)
HumanPlayer.__index = HumanPlayer

local LimbHealth = {
	Head = 50,
	UpperTorso = 85,
	LowerTorso = 70,
	LeftUpperArm = 60,
	LeftLowerArm = 60,
	RightUpperArm = 999,
	RightLowerArm = 999,
	LeftUpperLeg = 40,
	LeftLowerLeg = 40,
	RightUpperLeg = 40,
	RightLowerLeg = 40,
}

function HumanPlayer.new(humanoid: Humanoid, player: Player?)
	assert(player, "HumanPlayer constructor needs a valid player instance!")
	local self = setmetatable(Human.new(humanoid), HumanPlayer)

	Human.AssignBodyParts(self, "Player")
	self:SetupBloodEmitters()
	self.Player = player
	self.ClassType = "HumanPlayer"
	self.HumanType = "Player"
	self:InitializeWeaponLoadout()

	self.BodyParts["RightUpperArm"]:SetNetworkOwner(player)
	if CollectionService:HasTag(player, "FirstLoad") then
		warn("Player first loaded, setting invincible forever until game loaded")
		self:SetInvincible(true, true)
	else
		self:SetInvincibleFor(HumanConstants.ON_SPAWN_INVICIBILITY_TIME, true)
	end

	self:SetupMovementDetector()
	print(`New Human class initialized for {self.Player.DisplayName}`)

	return self :: any
end

function HumanPlayer:InitializeWeaponLoadout()
	local savedGunName = ServerData.GetWeaponName(self.Player)
	local savedThrowableData = ServerData.GetThrowableData(self.Player)
	local savedTrapData = ServerData.GetTrapData(self.Player)

	-- Gun
	self.Inventory:AddWeaponToInventory(savedGunName or "Revolver")
	self.Inventory:EquipWeapon("Gun")

	self.Inventory:AddWeaponToInventory(
		savedThrowableData and savedThrowableData.Name or "Molotov",
		savedThrowableData and savedThrowableData.Ammo or 9
	)
	self.Inventory:EquipWeapon("Throwable")

	-- self.Inventory:AddWeaponToInventory(savedTrapData or "BearTrap")
	-- self.Inventory:EquipWeapon("Trap")

	if savedThrowableData then
		-- Throwable
		local throwable = self.Inventory:AddWeaponToInventory(savedThrowableData.Name)
		if throwable then
			self.Inventory:EquipWeapon("Throwable")
		end
	end
end

function HumanPlayer:Ragdoll(duration: number)
	HumanSignals.RagdollClient:Fire(self.Player, duration)
end

function HumanPlayer:ApplyImpulse(force: Vector3, position: Vector3?)
	HumanSignals.ApplyImpulseToClient:Fire(self.Player, self.HRP, force, position)
end

function HumanPlayer:ConnectGUIs()
	self.Character:SetAttribute("Stamina", 100)
	HumanSignals.ConnectHumanGUIs:Fire(self.Player, self.Humanoid)
end

function HumanPlayer:SetInCombat(InCombat: boolean)
	Human.SetInCombat(self, InCombat)
	local InCombatGUI = Utility.GetInstance(self.Player, false, "PlayerGui", "InCombatGUI")
	if not InCombatGUI then
		warn("Cannot enable In Combat GUI, missing playerGUI reference")
		return
	end

	if InCombat then
		InCombatGUI.Enabled = true
	else
		InCombatGUI.Enabled = false
	end
end
function HumanPlayer:SetupMovementDetector()
	local humanoid = self.Humanoid
	self.Janitor:Add(humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 then
			self.Moving = true
		else
			self.Moving = false
			if self.Sprinting then
				self:ToggleSprinting(false)
			end
		end
	end))
end

function HumanPlayer:ToggleSprinting(active: boolean, bypassMovingRequirement: boolean?)
	local stamina = self.Stamina
	if self:IsLegless() then
		return
	end

	if self.Sprinting == active then
		return
	end

	local inventory = self and self.Inventory
	local gun = inventory and inventory:GetGun()
	local isHoldingGun = gun and gun.HoldingGun
	local sprintSpeed = if isHoldingGun
		then HumanConstants.SPRINT_SPEED * gun.EquipWalkspeedMultiplier
		else HumanConstants.SPRINT_SPEED
	local walkSpeed = if isHoldingGun
		then HumanConstants.WALKSPEED * gun.EquipWalkspeedMultiplier
		else HumanConstants.WALKSPEED

	if active and stamina and stamina > 0 and (bypassMovingRequirement or self.Moving) then
		self.Humanoid.WalkSpeed = sprintSpeed
		stamina = math.clamp(stamina, 0, HumanConstants.MAX_STAMINA)
		self.Sprinting = true
		ServerScreenEffects:StartSustainEffect(self.Player, "Sprinting")
	else
		self.Humanoid.WalkSpeed = walkSpeed
		self.Sprinting = false
		ServerScreenEffects:StopAllSustainEffects(self.Player)
	end
end

function HumanPlayer:DropMoney()
	local currentMoney = ServerData.GetMoney(self.Player)
	if currentMoney and currentMoney > 0 then
		local loss = math.floor(currentMoney * HumanConstants.ON_DEATH_MONEY_LOSS_MULTIPLIER)
		ServerData.SetMoney(self.Player, loss)
		if loss ~= 0 then
			MoneyDropHandler.DropMoney(self.Character:GetPivot().Position, loss)
		end
	end
end

function HumanPlayer:Die(killer: Player?)
	local dead = Human.Die(self)

	if not dead then
		return
	end

	if self.Player == killer then
		return
	end
	-- shooter should get a money reward for killing, but not if they've somehow killed themselves.
	if killer and typeof(killer) ~= "table" then
		if killer:IsA("Player") then
			warn("PLAYER KILLED PLAYAH")
			AwardHandler.AwardPlayerKill(self.Player, killer)
		else
			if CollectionService:HasTag(killer, "Sheriff") then
				warn("SHERIFF KILLED PLAYAH")
				CollectionService:AddTag(self.Player, "Jailed")
				ServerData:SetJailed(self.Player, true)
			end
		end
	end
end

function HumanPlayer:OnHit(damage: number, damageMultiplier: number, limbName: string, shooter: Player | Model)
	Human.OnHit(self, damage, damageMultiplier, limbName, shooter)

	-- update limb hp gui, changing limb health colour green->orange->red
	HumanLimbGUI:UpdateLimbGUIHP(self.Player, limbName, self.LimbHealth[limbName] / LimbHealth[limbName])
end

function HumanPlayer:DestroyLimb(limbName: string)
	Human.DestroyLimb(self, limbName)
	HumanLimbGUI:UpdateLimbGUIHP(self.Player, limbName, nil)
end

function HumanPlayer:RevertCrawlState()
	if not self:IsLegless() then
		return
	end

	-- Revert animation folder back to default on client
	AnimationHandler:ResetToDefaultAnimations(self.Player)
	--AnimationHandler:SetAnimationFolder(self.Player, "DefaultAnimations", nil)

	-- Re-enable HRP collision
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CanCollide = true
	end

	-- Restore jump, walk speed, and hip height
	self.Humanoid.UseJumpPower = false
	self.Humanoid.WalkSpeed = HumanConstants.WALKSPEED
	self.Humanoid.HipHeight = 2.142

	local currentGun = self.Inventory:GetGun()
	if currentGun then
		currentGun:ToggleCollision(true)
	end

	self:UpdateLeglessState(false)
end
function HumanPlayer:SetCrawlState()
	if self.Dead then
		return
	end

	if self:IsLegless() then
		return
	end

	local parts = self.DisabledBodyParts

	local currentGun = self.Inventory:GetGun()
	if currentGun then
		currentGun:ToggleCollision(false)
	end

	if (parts["LeftUpperLeg"] or parts["LeftLowerLeg"]) and (parts["RightUpperLeg"] or parts["RightLowerLeg"]) then
		warn("Should be crawling")

		HumanSignals.RagdollClient:Fire(self.Player, 3)
		print("Both legs disabled")

		-- set crawl anims
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		hrp.CanCollide = false
		AnimationHandler:SetAnimationFolder(self.Player, "CrawlAnimations", nil)

		self.Humanoid.UseJumpPower = true
		self.Humanoid.JumpPower = 0
		self.Humanoid.WalkSpeed = HumanConstants.CRAWL_SPEED
		self.Humanoid.HipHeight = 2

		self:FixCrawlADS()

		self:UpdateLeglessState(true)

		warn(`Player should be legless now`)
	end
end
function HumanPlayer:HealAll()
	Human.HealAll(self)

	-- update limb gui hp for all limbs to green again
	task.spawn(function()
		for key, bodyPart in self.BodyParts do
			if not bodyPart then
				continue
			end

			if not LimbHealth[key] then
				continue
			end
			HumanLimbGUI:UpdateLimbGUIHP(self.Player, key, LimbHealth[key])
		end
	end)

	self:AdjustGrayscale()
end
-- scale gray screen tint on client via current health
function HumanPlayer:AdjustGrayscale()
	local hpPercent = self:GetHealthPercentage()
	HumanSignals.AdjustGrayscale:Fire(self.Player, -1 - -hpPercent)
end
return HumanPlayer
