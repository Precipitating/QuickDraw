local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local DamageModule = require(ServerScriptService.Server.DamageModule)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local TrapPlaceables = ReplicatedStorage.Shared.Templates.Traps
local TRAP_PLACE_STUDS_FORWARD = 5
local TRAP_PLACE_STUDS_DOWN = 10
local TrapActivatedLogic = {
	BearTrap = function(trapModel: Model?, hitPart: BasePart | MeshPart, hitHuman: Human, trapData)
		local activateSound = trapData.TrapActivatedSoundName
		ServerSoundHandler:Play3DOneShotToOthers(nil, activateSound, hitPart.CFrame)

		local data = {
			Damage = trapData.Damage,
			LimbHit = hitPart,
			TargetHuman = hitHuman,
			CanAffectShooter = false,
		} :: ClassTypes.TrapDamage

		DamageModule.DamageHuman(data)

		hitHuman:Ragdoll(5)

		if trapModel then
			trapModel:Destroy()
		end
	end,
}
local Trap = {}
Trap.__index = Trap

type Human = ClassTypes.Human

function Trap.new(trapName: string, humanRef: Human, ammo: number?, tool: Tool?)
	assert(humanRef, "Trap class initialization failed: Missing inventory ref")
	assert(tool, "Missing tool ref for new trap class")
	local self = setmetatable({}, Trap)
	local trapData = TrapData[trapName]
	if not trapData then
		warn("Trap class initialization failed: Trap name is invalid")
		return
	end
	self.Janitor = Janitor.new()
	self.Name = trapName
	self.Tool = self.Janitor:Add(tool)
	self.Damage = trapData.Damage
	self.CurrentAmmo = if ammo then ammo else trapData.MaxAmmo
	self.MaxAmmo = trapData.MaxAmmo

	self.Owner = humanRef
	return self
end

function Trap:UpdateAmmo(amount: number)
	if amount > 0 and self.CurrentAmmo >= self.MaxAmmo then
		return false
	end
	self.CurrentAmmo = math.max(0, self.CurrentAmmo + amount)
	if self.CurrentAmmo <= 0 then
		self.Owner.Inventory:RemoveWeapon("Trap")
	end
	return true
end

function Trap:Destroy()
	self.Janitor:Cleanup()

	self.Tool = nil
	self.Owner = nil
	self.Name = nil
	self.Damage = nil
	self.CurrentAmmo = nil
	self.MaxAmmo = nil

	setmetatable(self, nil)
	table.clear(self)
end

function Trap:ConnectTrap(trapCollider: BasePart)
	local trapName = self.Name
	if not trapCollider or not trapName then
		warn("[ConnectTrap] a parameter is nil")
		return
	end

	local trapData = TrapData[trapName]
	if not trapData then
		warn("[ConnectTrap] Trap name is not valid ")
		return
	end

	local human = self.Owner
	if not human then
		warn("[ConnectTrap] Missing human reference")
		return
	end

	trapCollider.Touched:Once(function(hitPart: BasePart)
		if not TrapActivatedLogic[trapName] then
			return
		end

		if self.Owner and self.Owner.Invincible then
			return
		end

		if self.Owner and self.Owner.Dead then
			return
		end

		local hitParent = hitPart and hitPart.Parent
		if not hitParent then
			return
		end

		if not hitParent:FindFirstChild("Humanoid") then
			return
		end

		TrapActivatedLogic[trapName](trapCollider.Parent, hitPart, human, trapData)
	end)
end

function Trap:Place()
	if not self.Tool then
		return
	end

	local character = self.Owner.Character
	if not character then
		return
	end

	-- Use HRP as raycast origin for consistency and no reliance on physics
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	-- Define raycast origin
	local rayCastPosition = hrp.Position + (hrp.CFrame.LookVector * TRAP_PLACE_STUDS_FORWARD)

	local placeRay = workspace:Raycast(rayCastPosition, -Vector3.yAxis * TRAP_PLACE_STUDS_DOWN)

	if not placeRay and self.Owner.Player then
		PopupGUI:NewPopup(self.Owner.Player, 2, "Cannot place trap, invalid floor or no floor found")
		return
	end

	local template = TrapPlaceables:FindFirstChild(`{self.Name}Placed`)

	if not template then
		return
	end

	template = template:Clone()

	template:PivotTo(CFrame.new(placeRay.Position))
	template.Parent = workspace

	self:ConnectTrap(template:FindFirstChild("Collision"))

	self:UpdateAmmo(-1)
end

return Trap
