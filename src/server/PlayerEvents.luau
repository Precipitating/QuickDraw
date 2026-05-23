local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ReplicatedStorage.Packages.DataService).server
local ServerData = require(script.Parent.ServerData)
local ClassTypes = require(ServerScriptService.Server.Classes.ClassTypes)
local HumanConstants = require(ServerScriptService.Server.Classes.Human.HumanConstants)
local PlayerManager = require(ServerScriptService.Server.Managers.Player.PlayerManager)
local SpawnHandler = require(script.Parent.SpawnHandler.SpawnHandler)
local PlayerCharacters = {}
type HumanPlayer = ClassTypes.HumanPlayer
Players.CharacterAutoLoads = false

local function InitializePlayer(player: Player, character: Model)
	local humanClass: HumanPlayer = PlayerManager:AddHumanClass(player)
	local humanoid: Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local bounty = ServerData.GetBounty(player)
	if not humanoid then
		error(`Missing humanoid for {player.DisplayName}`)
	end

	CollectionService:AddTag(character, "Player")
	if bounty > 0 then
		CollectionService:AddTag(character, "Wanted")
	end
	humanoid.WalkSpeed = 6

	PlayerCharacters[player] = humanClass

	-- should ragdoll
	humanoid.Died:Connect(function()
		ServerData.SaveWeaponEquipped(player, "Revolver")
		humanClass:DropMoney()
		humanClass:OnDeath()
		SpawnHandler:ResetTimerIfJailed(player)
		PlayerCharacters[player] = nil
		task.wait(3)
		if not player then
			return
		end
		SpawnHandler:SpawnPlayer(player, true)
	end)
	-- remove class if they leave
	humanoid.Destroying:Connect(function()
		humanClass:Destroy()
	end)

	if CollectionService:HasTag(player, "FirstLoad") then
		CollectionService:RemoveTag(player, "FirstLoad")
		task.delay(HumanConstants.ON_SPAWN_INVICIBILITY_TIME, function()
			humanClass:SetInvincible(false, false)
		end)
	end

	SpawnHandler:SpawnPlayer(player, false)

	-- task.wait(2)
	-- humanClass:DestroyLimb("LeftUpperArm")
	-- humanClass:DestroyLimb("LeftUpperLeg")
	-- humanClass:DestroyLimb("RightUpperLeg")
end

return {
	Players.PlayerAdded:Connect(function(player: Player)
		ServerData.WaitForPlayerData(player)
		ServerData:SetupLeaderboard(player)
		ServerData:SetupDataServiceEvents(player)
		CollectionService:AddTag(player, "FirstLoad")
		player.CharacterAdded:Connect(function(character)
			InitializePlayer(player, character)
		end)
	end),

	DataService:addPlayerRemovingCallback(function(player: Player, data: any): ()
		-- Perform any cleanup or save operations here
		local humanClass = PlayerCharacters[player]
		if not player or not humanClass then
			return
		end

		if humanClass.InCombat then
			ServerData.UpdateCombatLogged(player, true)
			ServerData.SaveWeaponEquipped(player, "Revolver")
			ServerData.SetBounty(player, 0)
			ServerData.SetMoney(player, 0)
			print(`{player.Name} combat logged`)
			return
		end

		if humanClass.CurrentGun then
			ServerData.SaveWeaponEquipped(player, humanClass.CurrentGun.GunName)
		end

		if humanClass.CurrentThrowable then
			ServerData.SaveThrowableEquipped(
				player,
				humanClass.CurrentThrowable.Name,
				humanClass.CurrentThrowable.CurrentAmmo
			)
		else
			data.equippedThrowable = nil
		end

		ServerData.SetMoney(player, ServerData.GetMoney(player))

		PlayerCharacters[player] = nil
		print(player.Name .. " is leaving with data:", data)
	end),
}
