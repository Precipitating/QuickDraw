local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local GunSignals = require(ServerScriptService.Server.Classes.Gun.GunSignals)
local PopupGUI = require(ServerScriptService.Server.GUI.PopupGUI)
local ServerSoundHandler = require(ServerScriptService.Server.Sound.ServerSoundHandler)
local TrapData = require(ReplicatedStorage.Shared.TrapData.TrapData)
local Utility = require(ReplicatedStorage.Shared.Utility.Utility)
local TrapPlaceables = ReplicatedStorage.Shared.Templates.Traps
local TRAP_PLACE_STUDS_FORWARD = 5
local TRAP_PLACE_STUDS_DOWN = 10
local TrapActivatedLogic = {
	BearTrap = function(trapModel: Model?, hitPart: BasePart | MeshPart, hitHuman: Human, trapData)
		local activateSound = trapData.TrapActivatedSoundName
		ServerSoundHandler:Play3DOneShotToOthers(nil, activateSound, hitPart.CFrame)
		GunSignals.PlayerHit:Fire({ Instance = hitPart }, hitHuman.Humanoid, trapData.Damage, nil, trapModel, false)

		hitHuman:Ragdoll(5)

		if hitPart and hitPart.Parent then
			hitPart.Parent:Destroy()
		end
	end,
}
local Trap = {}
Trap.__index = Trap

type Human = ClassTypes.Human

function Trap.new(trapName: string, humanRef: Human, ammo: number?, tool: Tool?)
	assert(humanRef, "Trap class initialization failed: Missing inventory ref")
	local self = setmetatable({}, Trap)
	local trapData = TrapData[trapName]
	if not trapData then
		warn("Trap class initialization failed: Trap name is invalid")
		return
	end
	self.Name = trapName
	self.Tool = tool
	self.Damage = trapData.Damage
	self.CurrentAmmo = if ammo then ammo else trapData.MaxAmmo
	self.MaxAmmo = trapData.MaxAmmo
	self.Janitor = Janitor.new()
	self.Owner = humanRef
	return self
end

function Trap:UpdateAmmo(amount: number)
	self.CurrentAmmo = math.max(0, self.CurrentAmmo + amount)
	if self.CurrentAmmo <= 0 then
		self.Owner.Inventory:RemoveWeapon("Trap")
	end
	return true
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

	-- Get tool position
	local handle: BasePart = Utility.GetInstance(self.Tool, false, "Handle")

	-- Define raycast origin
	local rayCastPosition = handle.Position + (handle.CFrame.LookVector * TRAP_PLACE_STUDS_FORWARD)

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

	template.Position = placeRay.Position
	template.Parent = workspace

	self:ConnectTrap(template:FindFirstChild("Collider"))
end

return Trap
