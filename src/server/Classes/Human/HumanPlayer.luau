local ServerScriptService = game:GetService("ServerScriptService")
-- inheriting Human and defining Player only data
local AnimationHandler = require(ServerScriptService.Server.Animation.AnimationHandler)
local Gun = require(ServerScriptService.Server.Classes.Gun)
local Throwable = require(ServerScriptService.Server.Classes.Throwable.Throwable)
local Human = require(script.Parent.Human)
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
	self.CurrentThrowable = Throwable.new("Molotov", self)
	self.CurrentGun:AddGunToInventory()
	self.CurrentThrowable:AddThrowableToInventory()
	self.BodyParts["RightUpperArm"]:SetNetworkOwner(player)

	print(`New Human class initialized for {self.Player.DisplayName}`)
	return self :: any
end
function HumanPlayer:ApplyImpulse(force: Vector3, position: Vector3?)
	HumanSignals.ApplyImpulseToClient:Fire(self.Player, self.RootPart, force, position)
end

function HumanPlayer:ConnectGUIs()
	HumanSignals.ConnectHumanGUIs:Fire(self.Player, self.Humanoid)
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
		self.Humanoid.WalkSpeed = 8
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
