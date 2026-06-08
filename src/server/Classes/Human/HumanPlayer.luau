local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local AwardHandler = require(ServerScriptService.Server.AwardHandler.AwardHandler)
local MoneyDropHandler = require(ServerScriptService.Server.MoneyDropHandler)
local ServerData = require(ServerScriptService.Server.ServerData)

local Human = require(script.Parent.Human)
local HumanConstants = require(script.Parent.HumanConstants)
local HumanSignals = require(script.Parent.HumanSignals)
local HumanPlayer = setmetatable({}, Human)
HumanPlayer.__index = HumanPlayer

function HumanPlayer.new(humanoid: Humanoid, player: Player?)
	assert(player, "HumanPlayer constructor needs a valid player instance!")
	local self = setmetatable(Human.new(humanoid), HumanPlayer)

	Human.AssignBodyParts(self, "Player")
	self:SetupBloodEmitters()
	self.Player = player
	self.HumanType = "Player"
	self:InitializeWeaponLoadout()

	self.BodyParts["RightUpperArm"]:SetNetworkOwner(player)
	if CollectionService:HasTag(player, "FirstLoad") then
		warn("Player first loaded, setting invincible forever until game loaded")
		self:SetInvincible(true, true)
	else
		self:SetInvincibleFor(HumanConstants.ON_SPAWN_INVICIBILITY_TIME, true)
	end

	print(`New Human class initialized for {self.Player.DisplayName}`)

	return self :: any
end

function HumanPlayer:InitializeWeaponLoadout()
	local savedGunName = ServerData.GetWeaponName(self.Player)
	local savedThrowableData = ServerData.GetThrowableData(self.Player)

	-- Gun
	self.Inventory:AddWeaponToInventory(savedGunName or "Revolver")
	self.Inventory:EquipWeapon("Gun")

	self.Inventory:AddWeaponToInventory("HookGrenade", 9)
	self.Inventory:EquipWeapon("Throwable")

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
	HumanSignals.ApplyImpulseToClient:Fire(self.Player, self.RootPart, force, position)
end

function HumanPlayer:ConnectGUIs()
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
	if killer then
		if killer:IsA("Player") then
			warn("PLAYER KILLED PLAYAH")
			AwardHandler.AwardPlayerKill(self.Player, killer)
		else
			if CollectionService:HasTag(killer, "Sheriff") then
				warn("SHERIFF KILLED PLAYAH")
				CollectionService:AddTag(self.Player, "Jailed")
			end
		end
	end
end

function HumanPlayer:RevertCrawlState()
	if not self.Legless then
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

	self.Legless = false
end
function HumanPlayer:SetCrawlState()
	if self.Dead then
		return
	end

	if self.Legless then
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

		self.Legless = true

		warn(`Player should be legless now`)
	end
end
function HumanPlayer:HealAll()
	Human.HealAll(self)
	self:AdjustGrayscale()
end
-- scale gray screen tint on client via current health
function HumanPlayer:AdjustGrayscale()
	local hpPercent = self:GetHealthPercentage()
	HumanSignals.AdjustGrayscale:Fire(self.Player, -1 - -hpPercent)
end
return HumanPlayer
