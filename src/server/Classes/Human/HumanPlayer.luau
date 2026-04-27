local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local AwardHandler = require(ServerScriptService.Server.AwardHandler.AwardHandler)
local Gun = require(ServerScriptService.Server.Classes.Gun.Gun)

local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)

local Human = require(script.Parent.Human)
local HumanConstants = require(script.Parent.HumanConstants)
local HumanSignals = require(script.Parent.HumanSignals)
local HumanPlayer = setmetatable({}, Human)
HumanPlayer.__index = HumanPlayer

function HumanPlayer.new(humanoid: Humanoid, player: Player?)
	assert(player, "HumanPlayer constructor needs a valid player instance!")
	local self = setmetatable(Human.new(humanoid), HumanPlayer)
	Human.AssignBodyParts(self, "Player")
	self.Player = player
	self.HumanType = "Player"
	self.CurrentGun = Gun.new("Winchester", self, player)
	self.CurrentGun:AddGunToInventory()
	self.CurrentThrowable = Throwable.new("KetchumGrenade", self)

	self.CurrentThrowable:AddThrowableToInventory()
	self.BodyParts["RightUpperArm"]:SetNetworkOwner(player)

	self:OnSpawnInitialize()

	print(`New Human class initialized for {self.Player.DisplayName}`)
	return self :: any
end

function HumanPlayer:Ragdoll(duration: number)
	HumanSignals.RagdollClient:Fire(self.Player, duration)
end

function HumanPlayer:OnSpawnInitialize()
	self.Invincible = true
	task.delay(HumanConstants.ON_SPAWN_INVICIBILITY_TIME, function()
		if self and not CollectionService:HasTag(self.Character, "Dead") then
			self.Invincible = false
		end
	end)
end
function HumanPlayer:ApplyImpulse(force: Vector3, position: Vector3?)
	HumanSignals.ApplyImpulseToClient:Fire(self.Player, self.RootPart, force, position)
end

function HumanPlayer:ChangeGun(newGun: string)
	if self.CurrentGun then
		self.CurrentGun:Destroy()
	end
	self.CurrentGun = Gun.new(newGun, self, self.Player)
end

function HumanPlayer:ConnectGUIs()
	HumanSignals.ConnectHumanGUIs:Fire(self.Player, self.Humanoid)
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
	if killer and killer:IsA("Player") then
		warn("PLAYER KILLED PLAYAH")
		AwardHandler.AwardPlayerKill(self.Player, killer)
	end
end

function Human:SetCrawlState()
	if self.Dead then
		return
	end
	local parts = self.DisabledBodyParts

	if (parts["LeftUpperLeg"] or parts["LeftLowerLeg"]) and (parts["RightUpperLeg"] or parts["RightLowerLeg"]) then
		warn("Should be crawling")
		if self.Legless then
			return
		end

		HumanSignals.RagdollClient:Fire(self.Player, 3)
		print("Both legs disabled")

		-- set crawl anims
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		hrp.CanCollide = false
		AnimationHandler:SetAnimationFolder(self.Player, "CrawlAnimations", nil)

		self.Humanoid.UseJumpPower = true
		self.Humanoid.JumpPower = 0
		self.Humanoid.WalkSpeed = HumanConstants.CRAWL_SPEED
		self.Humanoid.HipHeight = 0.5

		self:FixCrawlADS()

		self.Legless = true

		warn(`Player should be legless now`)
	end
end

-- scale gray screen tint on client via current health
function HumanPlayer:AdjustGrayscale()
	local hpPercent = self:GetHealthPercentage()
	HumanSignals.AdjustGrayscale:Fire(self.Player, -1 - -hpPercent)
end
return HumanPlayer
